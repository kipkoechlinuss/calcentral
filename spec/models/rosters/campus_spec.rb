describe Rosters::Campus do
  let(:term_yr) {'2014'}
  let(:term_cd) {'B'}
  let(:term_slug) {"#{term_yr}-#{term_cd}"}
  let(:user_id) {rand(99999).to_s}
  let(:student_user_id) {rand(99999).to_s}
  let(:ccn1) {rand(9999)}
  let(:ccn2) {rand(9999)}
  let(:enrolled_student_login_id) {rand(99999).to_s}
  let(:enrolled_student_student_id) {rand(99999).to_s}
  let(:waitlisted_student_login_id) {rand(99999).to_s}
  let(:waitlisted_student_student_id) {rand(99999).to_s}
  let(:catid) {"#{rand(999)}"}
  let(:campus_course_id) {"info-#{catid}-#{term_slug}"}
  let(:fake_campus) do
    {
      "#{term_slug}" => [{
        id: campus_course_id,
        term_yr: term_yr,
        term_cd: term_cd,
        catid: catid,
        dept: 'INFO',
        course_code: "INFO #{catid}",
        emitter: 'Campus',
        name: 'Data Rules Everything Around Me',
        role: 'Instructor',
        sections: [{
          ccn: ccn1,
          section_label: 'LEC 001'
        },
        {
          ccn: ccn2,
          section_label: 'LAB 001'
        }]
      }]
    }
  end

  let(:fake_campus_student) do
    {
      "#{term_slug}" => [{
        id: campus_course_id,
        term_yr: term_yr,
        term_cd: term_cd,
        catid: catid,
        dept: 'INFO',
        dept_desc: 'Information Science',
        course_code: "INFO #{catid}",
        emitter: 'Campus',
        name: 'Fake Course Name',
        role: 'Student',
        sections: [{
          ccn: ccn1,
          section_label: 'LEC 001'
        }]
      }]
    }
  end

  shared_examples 'a good and proper roster' do
    it 'should return a list of officially enrolled students for a course ccn' do
      model = Rosters::Campus.new(user_id, course_id: campus_course_id)
      feed = model.get_feed
      expect(feed[:campus_course][:id]).to eq campus_course_id
      expect(feed[:campus_course][:name]).to eq fake_campus["#{term_slug}"][0][:name]
      expect(feed[:sections].length).to eq 2
      expect(feed[:sections][0][:ccn]).to eq ccn1
      expect(feed[:sections][0][:name]).to eq "INFO #{catid} LEC 001"
      expect(feed[:sections][1][:ccn]).to eq ccn2
      expect(feed[:sections][1][:name]).to eq "INFO #{catid} LAB 001"
      expect(feed[:students].length).to eq 2

      student = feed[:students][0]
      expect(student[:id]).to eq enrolled_student_login_id
      expect(student[:student_id]).to eq enrolled_student_student_id
      expect(student[:first_name]).to be_present
      expect(student[:last_name]).to be_present
      expect(student[:email]).to be_present
      expect(student[:sections].length).to eq 2
      expect(student[:sections][0][:ccn]).to eq ccn1
      expect(student[:sections][0][:name]).to eq "INFO #{catid} LEC 001"
      expect(student[:sections][1][:ccn]).to eq ccn2
      expect(student[:sections][1][:name]).to eq "INFO #{catid} LAB 001"
      expect(student[:profile_url]).to be_present
    end

    it 'should show official photo links for students who are not waitlisted in all sections' do
      model = Rosters::Campus.new(user_id, course_id: campus_course_id)
      feed = model.get_feed
      expect(feed[:sections].length).to eq 2
      expect(feed[:students].length).to eq 2
      expect(feed[:students].index {|student| student[:id] == waitlisted_student_login_id &&
          student[:photo].nil?
      }).to_not be_nil
    end
  end

  context 'a course with two sections' do
    before do
      expect(Berkeley::Terms).to receive(:legacy?).exactly(2).times.and_return is_legacy
      allow(CampusOracle::UserCourses::All).to receive(:new).with(user_id: user_id).and_return(double(get_all_campus_courses: fake_oracle))
      allow(CampusOracle::UserCourses::All).to receive(:new).with(user_id: student_user_id).and_return(double(get_all_campus_courses: fake_oracle_student))
      allow(EdoOracle::UserCourses::All).to receive(:new).with(user_id: user_id).and_return(double(get_all_campus_courses: fake_edo))
      allow(EdoOracle::UserCourses::All).to receive(:new).with(user_id: student_user_id).and_return(double(get_all_campus_courses: fake_edo_student))
    end

    context 'two-section course from legacy data' do
      let(:is_legacy) { true }
      let(:fake_oracle) { fake_campus }
      let(:fake_oracle_student) { fake_campus_student }
      let(:fake_edo) { {} }
      let(:fake_edo_student) { {} }
      before do
        expect(CampusOracle::Queries).to receive(:get_enrolled_students).with(ccn1, term_yr, term_cd).and_return(fake_students)
        expect(CampusOracle::Queries).to receive(:get_enrolled_students).with(ccn2, term_yr, term_cd).and_return(fake_students)
      end
      let(:fake_students) do
        [
          {
            'ldap_uid' => enrolled_student_login_id,
            'enroll_status' => 'E',
            'student_id' => enrolled_student_student_id,
            'first_name' => 'First Name',
            'last_name' => 'Last Name',
            'student_email_address' => "#{enrolled_student_login_id}@example.com",
          },
          {
            'ldap_uid' => waitlisted_student_login_id,
            'enroll_status' => 'W',
            'student_id' => waitlisted_student_student_id,
            'first_name' => 'First Name',
            'last_name' => 'Last Name',
            'student_email_address' => "#{waitlisted_student_login_id}@example.com",
          }
        ]
      end
      it_should_behave_like 'a good and proper roster'
    end

    context 'two-section course from Campus Solutions data' do
      let(:is_legacy) { false }
      let(:term_id) { Berkeley::TermCodes.to_edo_id(term_yr, term_cd) }
      let(:fake_oracle) { {} }
      let(:fake_oracle_student) { {} }
      let(:fake_edo) { fake_campus }
      let(:fake_edo_student) { fake_campus_student }
      before do
        expect(EdoOracle::Queries).to receive(:get_enrolled_students).with(ccn1, term_id).and_return primary_enrollments
        expect(EdoOracle::Queries).to receive(:get_enrolled_students).with(ccn2, term_id).and_return secondary_enrollments
        expect(User::BasicAttributes).to receive(:attributes_for_uids)
          .with([enrolled_student_login_id, waitlisted_student_login_id])
          .exactly(2).times.and_return attributes
      end
      let(:primary_enrollments) do
        [
          {
            'ldap_uid' => enrolled_student_login_id,
            'enroll_status' => 'E',
            'student_id' => enrolled_student_student_id,
            'grading_basis' => 'GRD',
            'units' => 4.0
          },
          {
            'ldap_uid' => waitlisted_student_login_id,
            'enroll_status' => 'W',
            'student_id' => waitlisted_student_student_id,
            'grading_basis' => 'ESU',
            'units' => 3.0
          }
        ]
      end
      let(:secondary_enrollments) do
        [
          {
            'ldap_uid' => enrolled_student_login_id,
            'enroll_status' => 'E',
            'student_id' => enrolled_student_student_id,
            'grading_basis' => 'NON',
            'units' => 0.0
          },
          {
            'ldap_uid' => waitlisted_student_login_id,
            'enroll_status' => 'W',
            'student_id' => waitlisted_student_student_id,
            'grading_basis' => 'NON',
            'units' => 0.0
          }
        ]
      end
      let(:attributes) do
        [
          {
            ldap_uid: enrolled_student_login_id,
            student_id: enrolled_student_student_id,
            first_name: 'First Name',
            last_name: 'Last Name',
            email_address: "#{enrolled_student_login_id}@example.com"
          },
          {
            ldap_uid: waitlisted_student_login_id,
            student_id: enrolled_student_student_id,
            first_name: 'First Name',
            last_name: 'Last Name',
            email_address: "#{waitlisted_student_login_id}@example.com"
          }
        ]
      end
      it_should_behave_like 'a good and proper roster'
      it 'should pick out stringified units and translated grade option from section with grade component' do
        feed = Rosters::Campus.new(user_id, course_id: campus_course_id).get_feed
        expect(feed[:students][0][:grade_option]).to eq 'Letter'
        expect(feed[:students][0][:units]).to eq '4.0'
        expect(feed[:students][1][:grade_option]).to eq 'S/U'
        expect(feed[:students][1][:units]).to eq '3.0'
      end
    end
  end

  context 'cross-listed courses', if: CampusOracle::Connection.test_data? do
    include_context 'instructor for crosslisted courses'
    let!(:crosslisted_course_id) do
      classes_for_instructor = MyClasses::Campus.new(instructor_id).fetch[:current]
      classes_for_instructor.first[:listings].first[:id]
    end

    it 'should merge sections for crosslisted courses' do
      feed = Rosters::Campus.new(instructor_id, course_id: crosslisted_course_id).get_feed
      expect(feed[:sections].length).to eq 6
    end
  end

end
