#***** BEGIN LICENSE BLOCK *****
#
#Version: RTV Public License 1.0
#
#The contents of this file are subject to the RTV Public License Version 1.0 (the
#"License"); you may not use this file except in compliance with the License. You
#may obtain a copy of the License at: http://www.osdv.org/license12b/
#
#Software distributed under the License is distributed on an "AS IS" basis,
#WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License for the
#specific language governing rights and limitations under the License.
#
#The Original Code is the Online Voter Registration Assistant and Partner Portal.
#
#The Initial Developer of the Original Code is Rock The Vote. Portions created by
#RockTheVote are Copyright (C) RockTheVote. All Rights Reserved. The Original
#Code contains portions Copyright [2008] Open Source Digital Voting Foundation,
#and such portions are licensed to you under this license by Rock the Vote under
#permission of Open Source Digital Voting Foundation.  All Rights Reserved.
#
#Contributor(s): Open Source Digital Voting Foundation, RockTheVote,
#                Pivotal Labs, Oregon State University Open Source Lab.
#
#***** END LICENSE BLOCK *****
require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe Registrant do
  include Rails.application.routes.url_helpers
  
  describe "default opt-in flags" do
    it "should be false for new records" do
      r = Registrant.new
      r.opt_in_email.should be_false
      r.opt_in_sms.should be_false
      r.volunteer.should be_false
      r.partner_opt_in_email.should be_false
      r.partner_opt_in_sms.should be_false
      r.partner_volunteer.should be_false
    end
  end
  
  describe "opt-in email flag" do
    it "should be false if there is no email address" do
      r= FactoryGirl.create(:maximal_registrant)
      r.opt_in_email.should be_true
      r.update_attributes(:email_address=>'', :collect_email_address=>'no')
      r.save!
      r.opt_in_email.should be_false
    end
  end
  
  describe "rtv_and_partner_name" do
    it "returns Rock the Vote when there's no partner" do
      r = Registrant.new
      r.stub(:partner) { nil }
      r.rtv_and_partner_name.should == "Rock the Vote"
      r.partner.stub(:primary?) { true }
      r.rtv_and_partner_name.should == "Rock the Vote"
    end
    it "returns both names when there is a partner" do
      r = Registrant.new
      p = FactoryGirl.create(:partner)
      r.stub(:partner) { p }
      r.rtv_and_partner_name.should == "Rock the Vote and #{p.organization}"
    end
  end
  
  describe "finish_iframe_url" do
    it "should be the default url with email address and partner ID passed in" do
      r = FactoryGirl.create(:step_5_registrant)
      r.finish_iframe_url.should == "#{Registrant::FINISH_IFRAME_URL}?locale=en&email=#{r.email_address}&partner_id=#{r.partner.id}"
    end
    it "should specify the locale and include tracking and source when present" do
      r = FactoryGirl.create(:step_5_registrant, :locale=>'es', :tracking_source=>'sourceval', :tracking_id=>'trackingval')
      r.finish_iframe_url.should == "#{Registrant::FINISH_IFRAME_URL}?locale=es&email=#{r.email_address}&partner_id=#{r.partner.id}&source=sourceval&tracking=trackingval"
    end
    it "uses a partner's iframe url as base for whitelabeled partners with non-blank values" do
      p1 = FactoryGirl.create(:partner, :whitelabeled=>false, :finish_iframe_url=>"https://www.google.com")
      p2 = FactoryGirl.create(:partner, :whitelabeled=>true, :finish_iframe_url=>"")
      p3 = FactoryGirl.create(:partner, :whitelabeled=>true, :finish_iframe_url=>"https://www.google.com")
      p3.stub(:primary?) { true }
      p4 = FactoryGirl.create(:partner, :whitelabeled=>true, :finish_iframe_url=>"https://www.google.com")

      r1 = FactoryGirl.create(:step_5_registrant, :partner=>p1)
      r2 = FactoryGirl.create(:step_5_registrant, :partner=>p2)
      r3 = FactoryGirl.create(:step_5_registrant, :partner=>p3)
      r4 = FactoryGirl.create(:step_5_registrant, :partner=>p4)
      
      r1.finish_iframe_url.should == "#{Registrant::FINISH_IFRAME_URL}?locale=en&email=#{r1.email_address}&partner_id=#{r1.partner.id}"
      r2.finish_iframe_url.should == "#{Registrant::FINISH_IFRAME_URL}?locale=en&email=#{r2.email_address}&partner_id=#{r2.partner.id}"
      r3.finish_iframe_url.should == "#{Registrant::FINISH_IFRAME_URL}?locale=en&email=#{r3.email_address}&partner_id=#{r3.partner.id}"
      
      r4.finish_iframe_url.should == "#{r4.partner.finish_iframe_url}?locale=en&email=#{r4.email_address}&partner_id=#{r4.partner.id}"
      
    end
  end
  
  describe "finish_with_state" do
    it "gets set to false for non-enabled states" do
      r = FactoryGirl.build(:step_3_registrant)
      r.stub(:home_state_online_reg_enabled?).and_return(false)
      r.finish_with_state = true
      r.save!
      r.finish_with_state.should be_false
    end
    it "can be set to true for enabled states" do
      r = FactoryGirl.build(:step_3_registrant)
      r.stub(:home_state_online_reg_enabled?).and_return(true)
      r.finish_with_state = true
      r.save!
      r.finish_with_state.should be_true      
    end
  end
  
  describe "#email_address_to_send_from" do
    before(:each) do
      @p = Partner.new
      @p.whitelabeled = true
      @p.from_email = "custom-from@rtv.org"
      @p.stub(:primary?) { false }
    end
    it "returns FROM_ADDRESS when partner is primary" do
      @p.stub(:primary?) { true }
      r = Registrant.new(:partner=>@p)
      r.email_address_to_send_from.should == RockyConf.from_address
    end
    it "returns FROM_ADDRESS when partner is not whitelabeled and from is configured" do
      @p.whitelabeled = false
      r = Registrant.new(:partner=>@p)
      r.email_address_to_send_from.should == RockyConf.from_address
    end
    it "returns FROM_ADDRESS when partner email is not configured" do
      @p.from_email = ''
      r = Registrant.new(:partner=>@p)
      r.email_address_to_send_from.should == RockyConf.from_address
    end
    it "returns the parter from_email when the parter is whitelabled and address is set" do
      r = Registrant.new(:partner=>@p)
      r.email_address_to_send_from.should == "custom-from@rtv.org"
    end
  end
  
  describe "backfill data" do
    it "backfills the age even when redacted" do
      assert_equal 0, Registrant.find(:all, :conditions => "age IS NOT NULL").size
      5.times { FactoryGirl.create(:step_5_registrant, :date_of_birth => 241.months.ago.to_date.to_s(:db)) }
      4.times { FactoryGirl.create(:step_5_registrant, :date_of_birth => 239.months.ago.to_date.to_s(:db)) }
      Registrant.update_all("age = NULL")
      Registrant.update_all("state_id_number = NULL")
      Registrant.backfill_data
      assert_equal 5, Registrant.find_all_by_age(20).size
      assert_equal 4, Registrant.find_all_by_age(19).size
    end

    it "backfills the official_party_name even when redacted" do
      assert_equal 0, Registrant.find(:all, :conditions => "party IS NOT NULL").size
      5.times { FactoryGirl.create(:step_5_registrant, :home_zip_code => "94103", :party => "Green") }
      5.times { FactoryGirl.create(:step_5_registrant, :home_zip_code => "94103", :party => "Verde", :locale => "es") }
      4.times { FactoryGirl.create(:step_5_registrant, :home_zip_code => "94103", :party => "Decline to State") }
      4.times { FactoryGirl.create(:step_5_registrant, :home_zip_code => "94103", :party => "Se niega a declarar", :locale => "es") }
      assert_equal 18, Registrant.find(:all, :conditions => "party IS NOT NULL").size
      Registrant.update_all("official_party_name = NULL")
      Registrant.update_all("state_id_number = NULL")
      Registrant.backfill_data
      assert_equal 10, Registrant.find_all_by_official_party_name("Green").size
      assert_equal 8, Registrant.find_all_by_official_party_name("None").size
    end

    it "backfills barcode" do
      assert_equal 0, Registrant.find(:all, :conditions => "barcode IS NOT NULL").size
      5.times { FactoryGirl.create(:step_1_registrant) }
      Registrant.update_all("barcode = NULL")
      Registrant.backfill_data
      regs = Registrant.find(:all, :conditions => "barcode IS NOT NULL")
      assert_equal 5, regs.size
      regs.each { |r| assert_match /\*RTV-[0-9A-Z]{6}\*/, r.barcode }
    end
  end

  describe "to_param hides id" do
    it "should be nil for new records" do
      reg = Registrant.new
      assert_nil reg.to_param
    end

    it "should be non nil for saved records" do
      reg = FactoryGirl.create(:step_1_registrant)
      assert_not_nil reg.to_param
    end

    it "should not be the record id" do
      reg = FactoryGirl.create(:step_1_registrant)
      assert_not_equal reg.id.to_s, reg.to_param
    end
  end

  describe "find_by_param" do
    it "should find record by url param" do
      reg = FactoryGirl.create(:step_1_registrant)
      assert_equal reg, Registrant.find_by_param(reg.to_param)
    end

    it "should raise AbandonedRecord when registrant is abandoned" do
      reg = FactoryGirl.create(:step_1_registrant, :abandoned => true)
      assert_raise Registrant::AbandonedRecord do
        Registrant.find_by_param(reg.to_param)
      end
    end

    it "should attach registrant to AbandonedRecord exception" do
      reg = FactoryGirl.create(:step_1_registrant, :abandoned => true)
      begin
        Registrant.find_by_param(reg.to_param)
      rescue Registrant::AbandonedRecord => exception
        assert_equal reg, exception.registrant
      end
    end
  end

  describe "localization" do
    it "finds the state localization" do
      reg = FactoryGirl.create(:step_5_registrant)
      loc = StateLocalization.find(:first, :conditions => {:state_id => reg.home_state_id, :locale => reg.locale})
      assert_equal loc, reg.localization
    end

    it "finds nothing if no home state or locale" do
      assert_nil Registrant.new.localization
      assert_nil Registrant.new(:home_state_id => 1).localization
      assert_nil Registrant.new(:locale => "en").localization
    end
  end

  describe "any step" do
    it "blanks party unless requires party" do
      reg = FactoryGirl.build(:maximal_registrant)
      reg.stub(:requires_party?) { false }
      assert reg.valid?
      assert reg.errors.full_messages
      assert_nil reg.party
    end
        
    it "parses date of birth before validation" do
      reg = FactoryGirl.build(:step_1_registrant)
      reg.date_of_birth = "08/27/1978"
      assert reg.valid?
      assert_equal Date.parse("Aug 27, 1978"), reg.date_of_birth
      reg.date_of_birth = "5/3/1978"
      assert reg.valid?
      assert_equal Date.parse("May 3, 1978"), reg.date_of_birth
      reg.date_of_birth = "5-3-1978"
      assert reg.valid?
      assert_equal Date.parse("May 3, 1978"), reg.date_of_birth

      reg.date_of_birth = "1978/5/3"
      assert reg.valid?
      assert_equal Date.parse("May 3, 1978"), reg.date_of_birth
      reg.date_of_birth = "1978-5-3"
      assert reg.valid?
      assert_equal Date.parse("May 3, 1978"), reg.date_of_birth

      reg.date_of_birth = "2/30/1978"
      assert reg.invalid?
      assert !reg.errors[:date_of_birth].empty?
      assert_equal "2/30/1978", reg.date_of_birth_before_type_cast
      reg.date_of_birth = "5-3-78"
      assert reg.invalid?
      assert !reg.errors[:date_of_birth].empty?
      assert_equal "5-3-78", reg.date_of_birth_before_type_cast
      reg.date_of_birth = "May 3, 1978"
      assert reg.invalid?
      assert !reg.errors[:date_of_birth].empty?
      assert_equal "May 3, 1978", reg.date_of_birth_before_type_cast
    end
  
    it "only allows ascii characters for PDF fields" do
      ascii_locales = [:en,  :tl, :ilo]
      non_ascii_locales = [:es, :zh, :vi, :"zh-tw", :hi, :ur, :bn, :ja, :ko, :th, :km]
      
      Registrant::PDF_FIELDS.each do |field|
        r = Registrant.new
        r.stub(:has_mailing_address?).and_return(true)
        r.stub(:change_of_name?).and_return(true)
        r.stub(:change_of_address?).and_return(true)
        
        #puts "testing field: #{field}"
        non_ascii_locales.each do |loc|
          txt = I18n.t('txt.registration.in_language_name', :locale=>loc, :default => "")
          unless txt.blank?
            #puts "\tTesting #{loc}: #{txt}"
            r.send("#{field}=",txt)
            r.should_not be_valid
            r.errors[field].should_not be_empty          
          end
        end
        ascii_locales.each do |loc|
          txt = I18n.t('txt.registration.in_language_name', :locale=>loc, :default => "").to_s +  " 123 !@$%^&*"
          # puts "\tTesting #{loc}: #{txt}"
          r.send("#{field}=",txt)
          r.valid?
          r.errors[field].should be_empty
        end
      end
    end
  
  end

  describe "step 1" do
    it "should require personal info" do
      assert_attribute_invalid_with(:step_1_registrant, :partner_id => nil)
      assert_attribute_invalid_with(:step_1_registrant, :locale => nil)
      assert_attribute_invalid_with(:step_1_registrant, :email_address => nil)
      assert_attribute_invalid_with(:step_1_registrant, :email_address => nil, :collect_email_address=>'yes')

      #FOR NOW
      assert_attribute_invalid_with(:step_1_registrant, :email_address => nil, :collect_email_address=>'optional')

      assert_attribute_invalid_with(:step_1_registrant, :email_address => nil, :collect_email_address=>'abc')

      assert_attribute_invalid_with(:step_1_registrant, :home_zip_code => nil, :home_state_id => nil)
      assert_attribute_invalid_with(:step_1_registrant, :home_zip_code => '00000')
      assert_attribute_invalid_with(:step_1_registrant, :date_of_birth => nil)
      assert_attribute_invalid_with(:step_1_registrant, :us_citizen => nil)
    end
    
    it "should require has_state_license" do
      reg = FactoryGirl.build(:step_1_registrant, :has_state_license=>nil)
      reg.invalid?
      assert reg.errors[:has_state_license]
    end
    
    it "should require will_be_18_by_election" do
      reg = FactoryGirl.build(:step_1_registrant, :will_be_18_by_election=>nil)
      reg.invalid?
      assert reg.errors[:will_be_18_by_election]
    end
    
    it "should not require email address when collect_email_address is 'no'" do
      assert_attribute_valid_with(:step_1_registrant, :email_address=>nil, :collect_email_address=>'no')
    end

    it "should limit number of simultaneous errors on home_zip_code" do
      reg = FactoryGirl.build(:step_1_registrant, :home_zip_code => nil)
      reg.invalid?

      assert_equal ["Required"], [reg.errors[:home_zip_code]].flatten
    end

    it "should check format of home_zip_code" do
      reg = FactoryGirl.build(:step_1_registrant, :home_zip_code => 'ABCDE')
      reg.invalid?

      assert_equal ["Use ZIP or ZIP+4"], [reg.errors[:home_zip_code]].flatten
    end

    it "should not require contact information" do
      assert_attribute_valid_with(:step_1_registrant, :name_title => nil)
      assert_attribute_valid_with(:step_1_registrant, :first_name => nil)
      assert_attribute_valid_with(:step_1_registrant, :last_name => nil)
      assert_attribute_valid_with(:step_1_registrant, :home_address => nil)
      assert_attribute_valid_with(:step_1_registrant, :home_city => nil)
    end

    it "should require email address is valid" do
      assert_attribute_invalid_with(:step_1_registrant, :email_address => "bogus")
      assert_attribute_invalid_with(:step_1_registrant, :email_address => "bogus@bogus")
      assert_attribute_invalid_with(:step_1_registrant, :email_address => "bogus@bogus.")
      assert_attribute_invalid_with(:step_1_registrant, :email_address => "@bogus.com")
    end

    it "should be ineligible when in state that doesn't participate" do
      reg = FactoryGirl.build(:step_1_registrant, :home_zip_code => '58001')  # North Dakota
      assert reg.valid?
      assert reg.ineligible?
      assert reg.ineligible_non_participating_state?
      reg = FactoryGirl.build(:step_1_registrant, :home_zip_code => '94101')  # California
      assert reg.valid?
      assert reg.eligible?
      assert !reg.ineligible_non_participating_state?
    end

    it "should be ineligible when too young" do
      reg = FactoryGirl.build(:step_1_registrant, :date_of_birth => 10.years.ago.to_date.to_s(:db))
      assert reg.valid?
      assert reg.ineligible?
      assert reg.ineligible_age?
      reg = FactoryGirl.build(:step_1_registrant, :date_of_birth => 20.years.ago.to_date.to_s(:db))
      assert reg.valid?
      assert reg.eligible?
      assert !reg.ineligible_age?
    end

    it "should be ineligible when not a citizen" do
      reg = FactoryGirl.build(:step_1_registrant, :us_citizen => false)
      assert reg.valid?
      assert reg.ineligible?
      assert reg.ineligible_non_citizen?
      reg = FactoryGirl.build(:step_1_registrant, :us_citizen => true)
      assert reg.valid?
      assert reg.eligible?
      assert !reg.ineligible_non_citizen?
    end
    
    it "does not validate phone is present if rtv or partner mobile opt-in is true" do
      reg = FactoryGirl.build(:step_1_registrant, :phone => "")
      reg.opt_in_sms = true
      reg.should be_valid
      reg.partner_opt_in_sms = true
      reg.should be_valid
    end
    
    
  end

  describe "step 2" do
    it "should require contact information" do
      assert_attribute_invalid_with(:step_2_registrant, :name_title => nil)
      assert_attribute_invalid_with(:step_2_registrant, :first_name => nil)
      assert_attribute_invalid_with(:step_2_registrant, :last_name => nil)
      assert_attribute_invalid_with(:step_2_registrant, :home_address => nil)
      assert_attribute_invalid_with(:step_2_registrant, :home_city => nil)
    end
    
    

    it "should not require state id" do
      assert_attribute_valid_with(:step_2_registrant, :state_id_number => nil)
    end

    it "requires mailing address fields if has_mailing_address" do
      assert_attribute_invalid_with(:step_2_registrant, :has_mailing_address => true, :mailing_address => nil)
      assert_attribute_invalid_with(:step_2_registrant, :has_mailing_address => true, :mailing_city => nil)
      assert_attribute_invalid_with(:step_2_registrant, :has_mailing_address => true, :mailing_state_id => nil)
      assert_attribute_invalid_with(:step_2_registrant, :has_mailing_address => true, :mailing_zip_code => nil)
    end

    it "should check format of mailing_zip_code" do
      reg = FactoryGirl.build(:step_2_registrant, :has_mailing_address => true, :mailing_zip_code => 'ABCDE')
      reg.invalid?

      assert_equal ["Use ZIP or ZIP+4"], [reg.errors[:mailing_zip_code]].flatten
    end

    it "should limit number of simultaneous errors on mailing_zip_code" do
      reg = FactoryGirl.build(:step_2_registrant, :has_mailing_address => true, :mailing_zip_code => nil)
      reg.invalid?

      assert_equal ["Required"], [reg.errors[:mailing_zip_code]].flatten
    end

    it "blanks mailing address fields unless has_mailing_address" do
      reg = FactoryGirl.build(:maximal_registrant, :has_mailing_address => false)
      assert reg.valid?
      assert reg.errors.full_messages
      assert_nil reg.mailing_address
      assert_nil reg.mailing_unit
      assert_nil reg.mailing_city
      assert_nil reg.mailing_state_id
      assert_nil reg.mailing_zip_code
    end

    it "should require race but only for certain states" do
      reg = FactoryGirl.build(:step_2_registrant, :race => nil)
      reg.stub(:requires_race?) {true}
      assert reg.invalid?
      assert reg.errors[:race]
    end

    it "should not require race for some states" do
      reg = FactoryGirl.build(:step_2_registrant, :race => nil)
      reg.stub(:requires_race?) {false}
      assert reg.valid?
    end
    
    it "party included in validations when required by state" do
      reg = FactoryGirl.build(:step_2_registrant, :party => "bogus")
      reg.stub(:requires_party?) { true }
      reg.stub(:state_parties) { %w[Democratic Republican] }
      assert reg.invalid?
      assert reg.errors[:party]
    end

    it "party not included in validations when not required by state" do
      reg = FactoryGirl.build(:step_2_registrant, :party => nil)
      reg.stub(:requires_party?) { false }
      assert reg.valid?
    end
    
    context "with a custom step 2" do
      before(:each) do
        @reg = FactoryGirl.build(:step_2_registrant, :home_address=>nil)
        @reg.stub(:custom_step_2?) { true }        
      end
      it "does not require home_address" do
        @reg.home_address = nil
        @reg.invalid?
        assert @reg.errors[:home_address].empty?
      end
      it "does not require home_city" do
        @reg.home_city = nil
        @reg.invalid?
        assert @reg.errors[:home_city].empty?
      end
    
      it "should format phone as ###-###-####" do
        reg = FactoryGirl.build(:step_2_registrant, :phone => "1234567890", :phone_type => "mobile")
        reg.stub(:custom_step_2?) { true }
        assert reg.valid?
        assert_equal "123-456-7890", reg.phone
      end
      it "should require a valid phone number" do
        reg = FactoryGirl.build(:step_2_registrant, :phone_type => "Mobile")
        reg.stub(:custom_step_2?) { true }
        
        reg.phone = "1234567890"
        assert reg.valid?

        reg.phone = "123-456-7890"
        assert reg.valid?
        assert reg.errors.full_messages

        reg.phone = "(123) 456 7890x123"
        assert reg.valid?

        reg.phone = "123.456.7890 ext 123"
        assert reg.valid?

        reg.phone = "asdfg"
        assert !reg.valid?

        reg.phone = "555-1234"
        assert !reg.valid?
      end
      
      it "validates phone is present if rtv mobile opt-in is true" do
        reg = FactoryGirl.build(:step_2_registrant, :phone_type => "Mobile")
        reg.stub(:custom_step_2?) { true }
        reg.phone = ''
        
        reg.opt_in_sms = true
        reg.valid?.should be_false
        assert reg.errors[:phone]
      end

      it "validates phone is present if partner mobile opt-in is true" do
        reg = FactoryGirl.build(:step_2_registrant, :phone_type => "Mobile")
        reg.stub(:custom_step_2?) { true }
        reg.phone = ''

        reg.partner_opt_in_sms = true
        reg.valid?.should be_false
        assert reg.errors[:phone]
      end
      

      it "does not require party when state has custom step 2" do
        @reg.party=nil
        @reg.stub(:requires_party?) {true}
        assert @reg.valid?
        assert @reg.errors[:party].empty?
      end
      
      it "should not require race for any state" do
        @reg.race = nil
        @reg.stub(:requires_race?) {true}
        #assert @reg.valid?
        @reg.invalid?
        assert @reg.errors[:race].empty?
      end
    end
    
    context "with a short form" do
      before(:each) do
        @reg = FactoryGirl.build(:step_2_registrant, :state_id_number=>"1234", :opt_in_sms=>false)
        @reg.stub(:use_short_form?) { true }        
      end
      it "should format phone as ###-###-####" do
        @reg.phone = "1234567890"
        @reg.phone_type = "mobile"
        assert @reg.valid?
        assert_equal "123-456-7890", @reg.phone
      end
      it "should require a valid phone number" do
        @reg.phone_type = "Mobile"
        
        @reg.phone = "1234567890"
        assert @reg.valid?

        @reg.phone = "123-456-7890"
        assert @reg.valid?
        assert @reg.errors.full_messages

        @reg.phone = "(123) 456 7890x123"
        assert @reg.valid?

        @reg.phone = "123.456.7890 ext 123"
        assert @reg.valid?

        @reg.phone = "asdfg"
        assert !@reg.valid?

        @reg.phone = "555-1234"
        assert !@reg.valid?
      end
      
      it "validates phone is present if rtv mobile opt-in is true" do
        @reg.phone_type = "Mobile"
        @reg.phone = ''
        
        @reg.opt_in_sms = true
        @reg.valid?.should be_false
        assert @reg.errors[:phone]
      end

      it "validates phone is present if partner mobile opt-in is true" do
        @reg.phone_type = "Mobile"
        @reg.phone = ''

        @reg.partner_opt_in_sms = true
        @reg.valid?.should be_false
        assert @reg.errors[:phone]
      end
      it "should require valid state id" do
        assert_attribute_invalid_with(:step_2_registrant, :short_form=>true, :state_id_number => nil)

        assert_attribute_valid_with(  :step_2_registrant, :short_form=>true, :state_id_number => "NONE")
        assert_attribute_valid_with(  :step_2_registrant, :short_form=>true, :state_id_number => "none")

        assert_attribute_invalid_with(:step_2_registrant, :short_form=>true, :state_id_number => "123")
        assert_attribute_valid_with(  :step_2_registrant, :short_form=>true, :state_id_number => "1234")
        assert_attribute_invalid_with(:step_2_registrant, :short_form=>true, :state_id_number => "12345")
        assert_attribute_invalid_with(:step_2_registrant, :short_form=>true, :state_id_number => "123456")
        assert_attribute_valid_with(  :step_2_registrant, :short_form=>true, :state_id_number => "1234567")
        assert_attribute_valid_with(  :step_2_registrant, :short_form=>true, :state_id_number => "1"*42)
        assert_attribute_invalid_with(:step_2_registrant, :short_form=>true, :state_id_number => "1"*43)

        assert_attribute_valid_with(  :step_2_registrant, :short_form=>true, :state_id_number => "A234567")
        assert_attribute_valid_with(  :step_2_registrant, :short_form=>true, :state_id_number => "1-234567")
        assert_attribute_valid_with(  :step_2_registrant, :short_form=>true, :state_id_number => "*234567")
        assert_attribute_invalid_with(:step_2_registrant, :short_form=>true, :state_id_number => "$234567")
      end
      it "should upcase state id" do
        reg = FactoryGirl.build(:step_2_registrant, :short_form=>true, :state_id_number => "abc12345")
        assert reg.valid?
        assert_equal "ABC12345", reg.state_id_number
      end
      it "should require previous name fields if change_of_name" do
        assert_attribute_invalid_with(:step_2_registrant, :short_form=>true, :change_of_name => true, :prev_name_title => nil)
        assert_attribute_invalid_with(:step_2_registrant, :short_form=>true, :change_of_name => true, :prev_first_name => nil)
        assert_attribute_invalid_with(:step_2_registrant, :short_form=>true, :change_of_name => true, :prev_last_name => nil)
      end

      it "requires previous address fields if change_of_address" do
        assert_attribute_invalid_with(:step_2_registrant, :short_form=>true, :change_of_address => true, :prev_address => nil)
        assert_attribute_invalid_with(:step_2_registrant, :short_form=>true, :change_of_address => true, :prev_city => nil)
        assert_attribute_invalid_with(:step_2_registrant, :short_form=>true, :change_of_address => true, :prev_state_id => nil)
        assert_attribute_invalid_with(:step_2_registrant, :short_form=>true, :change_of_address => true, :prev_zip_code => nil)
        assert_attribute_invalid_with(:step_2_registrant, :short_form=>true, :change_of_address => true, :prev_zip_code => '00000')
      end

      it "should not require attestations" do
        assert_attribute_valid_with(:step_2_registrant, :short_form=>true, :attest_true => nil, :state_id_number=>"1234")
      end

      it "should check format of prev_zip_code" do
        reg = FactoryGirl.build(:step_2_registrant, :short_form=>true, :change_of_address => true, :prev_zip_code => 'ABCDE')
        reg.invalid?

        assert_equal ["Use ZIP or ZIP+4"], [reg.errors[:prev_zip_code]].flatten
      end

      it "should limit number of simultaneous errors on prev_zip_code" do
        reg = FactoryGirl.build(:step_2_registrant, :short_form=>true, :change_of_address => true, :prev_zip_code => nil)
        reg.invalid?

        assert_equal ["Required"], [reg.errors[:prev_zip_code]].flatten
      end


      it "should not require phone number" do
        reg = FactoryGirl.build(:step_2_registrant, :short_form=>true, :phone => "", :state_id_number=>"1234")
        assert reg.valid?
      end
    end

    it "generates barcode when entering Step 2" do
      reg = FactoryGirl.create(:step_1_registrant)
      reg.stub(:valid?) { true }
      reg.stub(:pdf_barcode) { "*RTV-00ROFL*" }
      reg.advance_to_step_2
      assert_equal "*RTV-00ROFL*", reg.barcode
    end
    
    
    it "should require previous name fields if change_of_name" do
      assert_attribute_invalid_with(:step_2_registrant, :change_of_name => true, :prev_name_title => nil)
      assert_attribute_invalid_with(:step_2_registrant, :change_of_name => true, :prev_first_name => nil)
      assert_attribute_invalid_with(:step_3_registrant, :change_of_name => true, :prev_last_name => nil)
    end

    it "requires previous address fields if change_of_address" do
      assert_attribute_invalid_with(:step_2_registrant, :change_of_address => true, :prev_address => nil)
      assert_attribute_invalid_with(:step_2_registrant, :change_of_address => true, :prev_city => nil)
      assert_attribute_invalid_with(:step_2_registrant, :change_of_address => true, :prev_state_id => nil)
      assert_attribute_invalid_with(:step_2_registrant, :change_of_address => true, :prev_zip_code => nil)
      assert_attribute_invalid_with(:step_2_registrant, :change_of_address => true, :prev_zip_code => '00000')
    end
    
    it "should check format of prev_zip_code" do
      reg = FactoryGirl.build(:step_2_registrant, :change_of_address => true, :prev_zip_code => 'ABCDE')
      reg.invalid?

      assert_equal ["Use ZIP or ZIP+4"], [reg.errors[:prev_zip_code]].flatten
    end

    it "should limit number of simultaneous errors on prev_zip_code" do
      reg = FactoryGirl.build(:step_2_registrant, :change_of_address => true, :prev_zip_code => nil)
      reg.invalid?

      assert_equal ["Required"], [reg.errors[:prev_zip_code]].flatten
    end

    it "blanks previous name fields unless change_of_name" do
      reg = FactoryGirl.build(:maximal_registrant, :change_of_name => false)
      assert reg.valid?
      assert_nil reg.prev_name_title
      assert_nil reg.prev_first_name
      assert_nil reg.prev_middle_name
      assert_nil reg.prev_last_name
      assert_nil reg.prev_name_suffix
    end

    it "blanks previous address fields unless change_of_address" do
      reg = FactoryGirl.build(:maximal_registrant, :change_of_address => false)
      assert reg.valid?
      assert_nil reg.prev_address
      assert_nil reg.prev_unit
      assert_nil reg.prev_city
      assert_nil reg.prev_state_id
      assert_nil reg.prev_zip_code
    end
    
    describe "phone validations" do
      
      it "should format phone as ###-###-####" do
        reg = FactoryGirl.build(:step_2_registrant, :phone => "1234567890", :phone_type => "mobile")
        assert reg.valid?
        assert_equal "123-456-7890", reg.phone
      end

      it "should not require phone number" do
        reg = FactoryGirl.build(:step_2_registrant, :phone => "")
        assert reg.valid?
      end

      it "should require a valid phone number" do
        reg = FactoryGirl.build(:step_2_registrant, :phone_type => "Mobile")
        reg.phone = "1234567890"
        assert reg.valid?

        reg.phone = "123-456-7890"
        assert reg.valid?
        assert reg.errors.full_messages

        reg.phone = "(123) 456 7890x123"
        assert reg.valid?

        reg.phone = "123.456.7890 ext 123"
        assert reg.valid?

        reg.phone = "asdfg"
        assert !reg.valid?

        reg.phone = "555-1234"
        assert !reg.valid?
      end

      it "should not require phone type when registrant does not provide phone" do
        reg = FactoryGirl.build(:step_2_registrant, :phone_type => "")
        assert reg.valid?
      end

      it "should require phone type when registrant provides phone" do
        reg = FactoryGirl.build(:step_2_registrant, :phone_type => "", :phone => "123-456-7890")
        assert !reg.valid?
      end
    end
    
  end

  describe "step 3" do

    context "when registrant uses a custom step 2" do
      before(:each) do
        @reg =  FactoryGirl.create(:step_3_registrant) 
        @reg.stub(:custom_step_2?) { true }
      end
      it "should require home address" do
        @reg.home_address=nil
        assert @reg.invalid?
        assert @reg.errors[:home_address]
      end
      it "should require home city" do
        @reg.home_city=nil
        assert @reg.invalid?
        assert @reg.errors_on(:home_city)
      end
      
      it "should require race but only for certain states" do
        reg = FactoryGirl.build(:step_3_registrant, :race => nil)
        reg.stub(:custom_step_2?) { true }
        reg.stub(:requires_race?) {true}
        assert reg.invalid?
        assert reg.errors[:race]
      end

      it "should not require race for some states" do
        reg = FactoryGirl.build(:step_3_registrant, :race => nil)
        reg.stub(:requires_race?) {false}
        reg.stub(:custom_step_2?) { true }
        assert reg.valid?
      end

      it "party included in validations when required by state" do
        reg = FactoryGirl.build(:step_3_registrant, :party => "bogus")
        reg.stub(:requires_party?) { true }
        reg.stub(:custom_step_2?) { true }
        reg.stub(:state_parties) { %w[Democratic Republican] }
        assert reg.invalid?
        assert reg.errors[:party]
      end

      it "party not included in validations when not required by state" do
        reg = FactoryGirl.build(:step_3_registrant, :party => nil)
        reg.stub(:requires_party?) { false }
        assert reg.valid?
      end
      
    end

    it "should require valid state id" do
      assert_attribute_invalid_with(:step_3_registrant, :state_id_number => nil)

      assert_attribute_valid_with(  :step_3_registrant, :state_id_number => "NONE")
      assert_attribute_valid_with(  :step_3_registrant, :state_id_number => "none")

      assert_attribute_invalid_with(:step_3_registrant, :state_id_number => "123")
      assert_attribute_valid_with(  :step_3_registrant, :state_id_number => "1234")
      assert_attribute_invalid_with(:step_3_registrant, :state_id_number => "12345")
      assert_attribute_invalid_with(:step_3_registrant, :state_id_number => "123456")
      assert_attribute_valid_with(  :step_3_registrant, :state_id_number => "1234567")
      assert_attribute_valid_with(  :step_3_registrant, :state_id_number => "1"*42)
      assert_attribute_invalid_with(:step_3_registrant, :state_id_number => "1"*43)

      assert_attribute_valid_with(  :step_3_registrant, :state_id_number => "A234567")
      assert_attribute_valid_with(  :step_3_registrant, :state_id_number => "1-234567")
      assert_attribute_valid_with(  :step_3_registrant, :state_id_number => "*234567")
      assert_attribute_invalid_with(:step_3_registrant, :state_id_number => "$234567")
    end

    it "should upcase state id" do
      reg = FactoryGirl.build(:step_3_registrant, :state_id_number => "abc12345")
      assert reg.valid?
      assert_equal "ABC12345", reg.state_id_number
    end

    
    

    it "should not require attestations" do
      assert_attribute_valid_with(:step_3_registrant, :attest_true => nil)
    end


    
    
    it "validates phone is present if rtv mobile opt-in is true" do
      reg = FactoryGirl.build(:step_3_registrant, :phone => "")
      
      reg.opt_in_sms = true
      reg.valid?.should be_false
      assert reg.errors[:phone]
    end

    it "validates phone is present if partner mobile opt-in is true" do
      reg = FactoryGirl.build(:step_3_registrant, :phone => "")

      reg.partner_opt_in_sms = true
      reg.valid?.should be_false
      assert reg.errors[:phone]
    end
    
    
  end

  describe "step 5" do
    it "requires attestations" do
      assert_attribute_invalid_with(:step_5_registrant, :attest_true => "0")
    end
  end


  describe "home state name" do
    it "gets name for state" do
      new_york = GeoState['NY']
      reg = FactoryGirl.build(:step_1_registrant, :home_zip_code => "00501")
      assert_equal new_york.name, reg.home_state_name
      reg.home_state = nil
      reg.home_state_name.should be_nil
      
    end
  end
  describe "home state abbr" do
    it "gets abbr for state" do
      new_york = GeoState['NY']
      reg = FactoryGirl.build(:step_1_registrant, :home_zip_code => "00501")
      assert_equal new_york.abbreviation, reg.home_state_abbrev
      reg.home_state = nil
      reg.home_state_abbrev.should be_nil
    end
  end
  
  [1, 2].each do |qnum|
    describe "#survey_question_#{qnum}" do
      context "when original_survey_question_#{qnum} is blank" do
        it "returns the partner question" do
          p = FactoryGirl.create(:whitelabel_partner)
          r = FactoryGirl.create(:maximal_registrant, :partner=>p)
          r2 = FactoryGirl.create(:maximal_registrant, :partner=>p, :locale=>"es")
          r.send("original_survey_question_#{qnum}=", '')
          r2.send("original_survey_question_#{qnum}=", '')
          r.send("survey_question_#{qnum}").should == p.send("survey_question_#{qnum}_en")
          r2.send("survey_question_#{qnum}").should == p.send("survey_question_#{qnum}_es")
        
          p.update_attributes("survey_question_#{qnum}_en"=>"new en #{qnum}", "survey_question_#{qnum}_es"=>"new es #{qnum}")
          r.reload
          r2.reload
          r.send("original_survey_question_#{qnum}=", '')
          r2.send("original_survey_question_#{qnum}=", '')
          r.send("survey_question_#{qnum}").should == "new en #{qnum}"
          r2.send("survey_question_#{qnum}").should == "new es #{qnum}"
        end
      end
      context "when original_survey_question_#{qnum} has been filled" do
        it "returns the original value" do
          p = FactoryGirl.create(:whitelabel_partner)
          orig_en = p.send("survey_question_#{qnum}_en")
          orig_es = p.send("survey_question_#{qnum}_es")
          r = FactoryGirl.create(:maximal_registrant, :partner=>p)
          r2 = FactoryGirl.create(:maximal_registrant, :partner=>p, :locale=>"es")
          r.send("survey_question_#{qnum}").should == orig_en
          r2.send("survey_question_#{qnum}").should == orig_es
      
          p.update_attributes("survey_question_#{qnum}_en"=>"new en #{qnum}", "survey_question_#{qnum}_es"=>"new es #{qnum}")
          r.reload
          r2.reload
          r.send("survey_question_#{qnum}").should == orig_en
          r2.send("survey_question_#{qnum}").should == orig_es
        end
      end
    end
    describe "original_survey_question_#{qnum}" do
      it "gets set on save when the question is answered" do
        p = FactoryGirl.create(:whitelabel_partner)
        r = FactoryGirl.create(:step_3_registrant, :partner=>p)
        r2 = FactoryGirl.create(:step_3_registrant, :partner=>p, :locale=>"es")
        r.send("survey_answer_#{qnum}").should be_blank
        r2.send("survey_answer_#{qnum}").should be_blank
        r.update_attributes("survey_answer_#{qnum}"=>"My Answer")
        r2.update_attributes("survey_answer_#{qnum}"=>"My Answer")
        r.reload
        r2.reload
        r.send("original_survey_question_#{qnum}").should == p.send("survey_question_#{qnum}_en")
        r2.send("original_survey_question_#{qnum}").should == p.send("survey_question_#{qnum}_es")
      end
    end
  end
  
  
  describe "OVR flows" do
    describe "in_ovr_flow?" do
      let(:reg) { FactoryGirl.build(:step_1_registrant) }
      it "is true when the registrant checked has-id and the registrant's state is enabled for ovr" do
        reg.has_state_license = true
        reg.stub(:home_state_allows_ovr?).and_return(true)
        reg.should be_in_ovr_flow
      end
      it "is false when the registrant did not chck has-id" do
        reg.has_state_license = false
        reg.stub(:home_state_allows_ovr?).and_return(true)
        reg.should_not be_in_ovr_flow
      end
      it "is false when the registrant's state is not enable for ovr" do
        reg.has_state_license = true
        reg.stub(:home_state_allows_ovr?).and_return(false)
        reg.should_not be_in_ovr_flow
      end
    end
    
    describe "home_state_allows_ovr?" do
      let(:reg) { FactoryGirl.build(:step_1_registrant) }
      it "pulls from the localization" do
        mock_loc = mock(StateLocalization)
        mock_loc.should_receive(:allows_ovr?)
        reg.stub(:localization).and_return(mock_loc)
        reg.home_state_allows_ovr?
      end
      context "when localization nil" do
        it "returns false" do
          reg.home_state_id = nil
          reg.home_state_allows_ovr?.should be_false
        end
      end
    end
  end
  
  describe "custom_step_2?" do
    it "returns true if the state has a custom step 2" do
      reg = FactoryGirl.build(:step_1_registrant)
      File.stub(:exists?).with(File.join(Rails.root,'app/views/step2/_pa.html.erb')) { true }
      GeoState.stub(:states_with_online_registration) { ["PA"] }
      reg.custom_step_2?.should be_true
    end
    it "returns false if javascript is disabled" do
      File.stub(:exists?).with(File.join(Rails.root,'app/views/step2/_pa.html.erb')) { true }
      reg = FactoryGirl.build(:step_1_registrant, :javascript_disabled=>true)
      reg.custom_step_2?.should be_false
    end
    it "returns false if the state has a custom step 2" do
      File.stub(:exists?).with(File.join(Rails.root,'app/views/step2/_pa.html.erb')) { false }
      reg = FactoryGirl.build(:step_1_registrant)
      reg.custom_step_2?.should be_false
    end    
    it "returns false if the state is missing" do
      File.stub(:exists?).with(File.join(Rails.root,'app/views/step2/_pa.html.erb')) { true }
      reg = FactoryGirl.build(:step_1_registrant)
      reg.home_state = nil
      reg.custom_step_2?.should be_false
    end
  end
  describe "custom_step_2_partial" do
    it "returns a filename of a view partial based on the state abbreviation" do
      reg = FactoryGirl.build(:step_2_registrant)
      reg.custom_step_2_partial.should == "pa"
    end
  end
  
  describe "has_home_state_online_registration_instructions?" do
    it "returns true if the state has a partial based on the state abbreviation" do
      reg = FactoryGirl.build(:step_1_registrant)
      File.stub(:exists?).with(File.join(Rails.root,'app/views/state_online_registrations/_pa_instructions.html.erb')) { true }
      reg.has_home_state_online_registration_instructions?.should be_true
    end    
  end
  describe "home_state_online_registration_instructions_partial" do
    it "returns a filename of a view partial based on the state abbreviation" do
      reg = FactoryGirl.build(:step_2_registrant)
      reg.home_state_online_registration_instructions_partial.should == "pa_instructions"
    end
  end


  describe "has_home_state_online_registration_view?" do
    it "returns true if the state has a partial based on the state abbreviation" do
      reg = FactoryGirl.build(:step_1_registrant)
      File.stub(:exists?).with(File.join(Rails.root,'app/views/state_online_registrations/pa.html.erb')) { true }
      reg.has_home_state_online_registration_view?.should be_true
    end    
  end
  describe "home_state_online_registration_view" do
    it "returns a filename of a view partial based on the state abbreviation" do
      reg = FactoryGirl.build(:step_2_registrant)
      reg.home_state_online_registration_view.should == "pa"
    end
  end

  describe "use_short_form?" do
    it "returns false if short_form is false" do
      r = Registrant.new(:short_form=>false)
      r.use_short_form?.should be_false
    end
    it "returns false if short_form is true and custom_step_2 is true" do
      r = Registrant.new(:short_form=>true)
      r.stub(:custom_step_2?) { true }
      r.use_short_form?.should be_false
    end
    it "return true if short_form is true and custom_step_2 is false" do
      r = Registrant.new(:short_form=>true)
      r.stub(:custom_step_2?) { false }
      r.use_short_form?.should be_true
    end
  end

  describe "#collect_email_address?" do
    it "is false for capitalizations and spacings of 'no'" do
      ['no', 'NO', 'No', 'nO', ' no', 'nO ', ' NO '].each do |v|
        r = Registrant.new(:collect_email_address=>v)
        r.collect_email_address?.should be_false
      end
    end
    it "is true for all other values" do
      ['n', '', nil, 'n-o', 'not', 'yes','optional'].each do |v|
        r = Registrant.new(:collect_email_address=>v)
        r.collect_email_address?.should be_true
      end
    end
  end
  describe "#require_email_address?" do
    # it "is false for all capitalizations and spacing of 'optional'" do
    #   ['optional', 'OPTIONAL', 'Optional', 'opTional', ' optionaL', 'OpTional ', ' optional '].each do |v|
    #     r = Registrant.new(:collect_email_address=>v)
    #     r.require_email_address?.should be_false
    #   end
    # end
    # TODO: For now "optional" still means required
    it "is TRUE for all capitalizations and spacing of 'optional'" do
      ['optional', 'OPTIONAL', 'Optional', 'opTional', ' optionaL', 'OpTional ', ' optional '].each do |v|
        r = Registrant.new(:collect_email_address=>v)
        r.require_email_address?.should be_true
      end
    end
    
    it "is false for all capitalizations and spacings of 'no'" do
      ['no', 'NO', 'No', 'nO', ' no', 'nO ', ' NO '].each do |v|
        r = Registrant.new(:collect_email_address=>v)
        r.require_email_address?.should be_false
      end
    end
    it "is true for all other values" do
      ['n', '', nil, 'n-o', 'not', 'yes','opional'].each do |v|
        r = Registrant.new(:collect_email_address=>v)
        r.require_email_address?.should be_true
      end
    end
  end

  describe "states by abbreviation" do
    it "sets state by abbreviation" do
      new_york = GeoState['NY']
      reg = FactoryGirl.build(:step_1_registrant, :mailing_state_abbrev => "NY", :prev_state_abbrev => "NY")
      assert_equal new_york.id, reg.mailing_state_id
      assert_equal new_york.id, reg.prev_state_id
    end

    it "gets abbrev for state" do
      new_york = GeoState['NY']
      reg = FactoryGirl.build(:step_1_registrant, :mailing_state => new_york, :prev_state => new_york)
      assert_equal new_york.abbreviation, reg.mailing_state_abbrev
      assert_equal new_york.abbreviation, reg.prev_state_abbrev
    end
  end

  describe "state parties" do
    it "gets parties by locale when required" do
      reg = FactoryGirl.build(:step_2_registrant, :locale => 'en', :home_zip_code => '94101')
      state = reg.home_state
      reg.localization.update_attributes(:parties => %w(red green blue), :no_party => "black")
      assert_equal %w(red green blue black), reg.state_parties
      reg.locale = 'es'
      reg.instance_variable_set(:@localization, nil)  # registrant memoizes localization so we have to clear it
      reg.localization.update_attributes(:parties => %w(red green blue), :no_party => "black")
      assert_equal %w(red green blue black), reg.state_parties
    end

    it "gets no parties when not required" do
      reg = FactoryGirl.build(:step_2_registrant, :home_state => GeoState["PA"])
      assert_equal nil, reg.state_parties
    end

    it "gets no parties when no locale" do
      reg = FactoryGirl.build(:step_2_registrant)
      reg.stub(:requires_party?) { true }
      reg.stub(:localization) { nil }
      reg.state_parties.should == []
    end

  end

  describe "calculate age" do
    it "sets age at time of application" do
      assert_age 17, 17.years + 1.day
      assert_age 17, 17.years
      assert_age 16, 17.years - 1.day
    end

    it "sets age when record is saved" do
      reg = FactoryGirl.create(:step_1_registrant, :date_of_birth => (18.years + 1.day).ago.to_date.strftime("%m/%d/%Y"))
      assert_equal 18, reg.age
    end
  end

  def assert_age(years, born_on)
    reg = FactoryGirl.build(:step_1_registrant, :date_of_birth => born_on.ago.to_date.strftime("%m/%d/%Y"))
    reg.created_at = Time.now.utc   # TODO: change to a US time zone
    reg.calculate_age
    assert_equal years, reg.age
  end

  describe "set official party name" do
    it "uses party attribute when in English locale" do
      reg = FactoryGirl.build(:step_5_registrant, :locale => "en", :home_zip_code => "94103", :party => "Green")
      assert reg.valid?
      assert_equal "Green", reg.official_party_name
    end

    it "maps Spanish party name to English" do
      reg = FactoryGirl.build(:step_5_registrant, :locale => "es", :home_zip_code => "94103", :party => "Verde")
      assert reg.valid?
      assert_equal "Green", reg.official_party_name
    end

    it "handles Decline to State" do
      reg = FactoryGirl.build(:step_5_registrant, :locale => "en", :home_zip_code => "94103", :party => "Decline to State")
      assert reg.valid?
      assert_equal "None", reg.official_party_name
    end

    it "handles Decline to State in Spanish" do
      reg = FactoryGirl.build(:step_5_registrant, :locale => "es", :home_zip_code => "94103", :party => "Se niega a declarar")
      assert reg.valid?
      assert_equal "None", reg.official_party_name
    end

    it "sets to None for states which do not require party" do
      reg = FactoryGirl.build(:maximal_registrant, :locale => "en", :home_zip_code => "02134", :party => nil)
      assert !reg.home_state.requires_party?
      assert reg.valid?
      assert_equal "None", reg.official_party_name
    end
  end

  describe "under_18_instructions_for_home_state" do
    it "shows instructions with state name and localized rule" do
      reg = FactoryGirl.build(:step_1_registrant)
      text = reg.under_18_instructions_for_home_state
      assert_match Regexp.compile(reg.home_state.name), text
      assert_match Regexp.compile(reg.localization.sub_18), text
    end
  end

  describe "at least step N" do
    it "should say whether step is at least N" do
      reg = FactoryGirl.build(:step_2_registrant)
      assert reg.at_least_step_1?
      assert reg.at_least_step_2?
      assert !reg.at_least_step_3?

    end
  end

  describe "#abandon!" do
    it "should mark as abandoned" do
      reg = FactoryGirl.create(:step_1_registrant)
      assert !reg.abandoned?
      reg.abandon!
      assert reg.abandoned?
    end

    it "should clear sensitive data" do
      reg = FactoryGirl.create(:step_4_registrant)
      assert_not_nil reg.state_id_number
      reg.abandon!
      assert_nil reg.state_id_number
    end
  end

  describe "stale records" do
    it "should become abandoned" do
      stale_rec = FactoryGirl.create(:step_4_registrant, :updated_at => (Registrant::STALE_TIMEOUT + 10).seconds.ago)
      fresh_rec = FactoryGirl.create(:step_4_registrant, :updated_at => (Registrant::STALE_TIMEOUT - 10).seconds.ago)
      complete_rec = FactoryGirl.create(:maximal_registrant, :updated_at => (Registrant::STALE_TIMEOUT + 10).seconds.ago)

      Registrant.abandon_stale_records

      assert stale_rec.reload.abandoned?
      assert !fresh_rec.reload.abandoned?
      assert !complete_rec.reload.abandoned?
    end
    it "should send an email if registrant chose to finish online with state" do
      GeoState.stub(:states_with_online_registration).and_return(['MA','PA'])
      
      stale_state_online_reg = FactoryGirl.create(:step_2_registrant, :updated_at => (Registrant::STALE_TIMEOUT + 10).seconds.ago, :finish_with_state=>true)
      stale_reg = FactoryGirl.create(:step_2_registrant, :updated_at => (Registrant::STALE_TIMEOUT + 10).seconds.ago, :finish_with_state=>false)
      
      expect {
        Registrant.abandon_stale_records
      }.to change { ActionMailer::Base.deliveries.count }.by(1)
      
    end
    it "should not send an email if registrant email is blank" do
      GeoState.stub(:states_with_online_registration).and_return(['MA','PA'])
      
      stale_state_online_reg = FactoryGirl.create(:step_2_registrant, 
        :updated_at => (Registrant::STALE_TIMEOUT + 10).seconds.ago, 
        :finish_with_state=>true, 
        :collect_email_address=>'no',
        :email_address=>nil)
      stale_reg = FactoryGirl.create(:step_2_registrant, :updated_at => (Registrant::STALE_TIMEOUT + 10).seconds.ago, :finish_with_state=>false)
      
      expect {
        Registrant.abandon_stale_records
      }.to change { ActionMailer::Base.deliveries.count }.by(0)      
    end
    
    it "should not send an email to registrants that have been thanked" do
      GeoState.stub(:states_with_online_registration).and_return(['MA','PA'])
      stale_state_online_reg = FactoryGirl.create(:step_2_registrant, :updated_at => (Registrant::STALE_TIMEOUT + 10).seconds.ago, :finish_with_state=>true)
      
      Registrant.abandon_stale_records
      
      
      stale_state_online_reg_2 = FactoryGirl.create(:step_2_registrant, :updated_at => (Registrant::STALE_TIMEOUT + 10).seconds.ago, :finish_with_state=>true)
      expect {
        Registrant.abandon_stale_records
      }.to change { ActionMailer::Base.deliveries.count }.by(1)
      
      expect {
        Registrant.abandon_stale_records
      }.to change { ActionMailer::Base.deliveries.count }.by(0)
      
    end
  end

  describe "PDF" do
    describe "merge" do
      before(:each) do
        @registrant = FactoryGirl.create(:maximal_registrant)
        @registrant.stub(:merge_pdf) { `touch #{@registrant.pdf_file_path}` }
      end

      it "generates PDF with merged data" do
        `rm -f #{@registrant.pdf_file_path}`
        assert_difference(%Q{Dir[File.join(Rails.root, "public/pdfs/#{@registrant.bucket_code}/*")].length}) do
          @registrant.generate_pdf
        end
      end

      it "returns PDF if already exists" do
        `touch #{@registrant.pdf_file_path}`
        assert_difference(%Q{Dir[File.join(Rails.root, "public/pdfs/#{@registrant.bucket_code}/*")].length} => 0) do
          @registrant.generate_pdf
        end
      end

      it "sets pdf_ready if file exists or is generated" do
        assert !@registrant.pdf_ready?
        @registrant.generate_pdf
        assert @registrant.pdf_ready?
      end

      after do
        `rm #{@registrant.pdf_file_path}`
        `rmdir #{File.dirname(@registrant.pdf_file_path)}`
      end
    end
  end

  describe "CSV" do
    it "renders minimal CSV" do
      reg = FactoryGirl.build(:step_1_registrant)
      partner = reg.partner
      partner.survey_question_1_en = "survey_question_1_en"
      partner.survey_question_2_en = "survey_question_2_en"
      assert_equal [ "Step 1",
                      nil,
                      nil,
                     "English",
                     reg.date_of_birth.to_s(:month_day_year),
                     reg.email_address,
                     "No",
                     "Yes",
                     nil,
                     nil,
                     nil,
                     nil,
                     nil,
                     nil,
                     nil,
                     nil,
                     "PA",
                     "15215",
                     "No",
                     nil,
                     nil,
                     nil,
                     nil,
                     nil,
                     nil,
                     nil,
                     nil,
                     nil,
                     "No",
                     "No",
                     "No",
                     "No",
                     "survey_question_1_en",
                     nil,
                     "survey_question_2_en",
                     nil,
                     "No",  # volunteer
                     "No",
                     nil,
                     nil,
                     "No",
                     "No"],
                  reg.to_csv_array
    end

    it "renders maximal CSV" do
      partner = FactoryGirl.create(:whitelabel_partner)
      reg = FactoryGirl.create(:api_v2_maximal_registrant, :partner=>partner)
      reg.update_attributes :home_zip_code => "94110", :party => "Democratic"
      assert_equal [ "Complete",
                     "tracking_source",
                     "part_tracking_id",
                     "English",
                     reg.date_of_birth.to_s(:month_day_year),
                     "citizen@example.com",
                     "No",
                     "Yes",
                     "Mrs.",
                     "Susan",
                     "Brownell",
                     "Anthony",
                     "III",
                     "123 Civil Rights Way",
                     "Apt 2",
                     "West Grove",
                     "CA",
                     "94110",
                     "Yes",
                     "10 Main St",
                     "Box 5",
                     "Adams",
                     "MA",
                     "02135",
                     "Democratic",
                     "White (not Hispanic)",
                     "123-456-7890",
                     "Mobile",
                     "Yes",
                     "Yes",
                     "Yes",
                     "Yes",
                     "color?",
                     "blue",
                     "dog name?",
                     "fido",
                     "Yes",
                     "Yes",
                     nil,
                     reg.created_at && reg.created_at.to_s(:month_day_year),
                     "No",
                     "Yes"
                     ],
                 reg.to_csv_array
    end

    it "renders maximal CSV with es questions for es locale" do
      reg = FactoryGirl.create(:api_v2_maximal_registrant, :locale => "es")
      partner = reg.partner
      partner.survey_question_1_es = "survey_question_1_es"
      partner.survey_question_2_es = "survey_question_2_es"
      reg.update_attributes :home_zip_code => "94110", :party => "Democratic"
      reg.to_csv_array.should == [ "Complete",
                     "tracking_source",
                     "part_tracking_id",
                     "Spanish",
                     reg.date_of_birth.to_s(:month_day_year),
                     "citizen@example.com",
                     "No",
                     "Yes",
                     "Mrs.",
                     "Susan",
                     "Brownell",
                     "Anthony",
                     "III",
                     "123 Civil Rights Way",
                     "Apt 2",
                     "West Grove",
                     "CA",
                     "94110",
                     "Yes",
                     "10 Main St",
                     "Box 5",
                     "Adams",
                     "MA",
                     "02135",
                     "Democratic",
                     "White (not Hispanic)",
                     "123-456-7890",
                     "Mobile",
                     "Yes",
                     "Yes",
                     "Yes",
                     "Yes",
                     "color?",
                     "blue",
                     "dog name?",
                     "fido",
                     "Yes",
                     "Yes",
                     nil,
                     reg.created_at && reg.created_at.to_s(:month_day_year),
                     "No",
                     "Yes"
                     ]
                 
    end

    it "renders ineligible CSV" do
      reg = FactoryGirl.create(:step_1_registrant, :us_citizen => false)
      assert_equal "Not a US citizen", reg.to_csv_array[-4]
    end

    it "has a CSV header" do
      assert_not_nil Registrant::CSV_HEADER

      reg = FactoryGirl.build(:maximal_registrant)
      assert_equal Registrant::CSV_HEADER.size, reg.to_csv_array.size
    end
  end

  describe "wrapping up" do
    it "should transition to complete state" do
      reg = FactoryGirl.create(:step_5_registrant)
      reg.stub(:complete_registration)
      reg.wrap_up
      assert reg.reload.complete?
    end

    it "clears out sensitive data" do
      reg = FactoryGirl.create(:step_5_registrant, :state_id_number => "1234567890")
      reg.stub(:generate_pdf)                  # avoid messy out-of-band action in tests
      reg.stub(:deliver_confirmation_email)    # avoid messy out-of-band action in tests
      reg.stub(:enqueue_reminder_emails)       # avoid messy out-of-band action in tests
      reg.complete_registration
      assert_nil reg.state_id_number
    end

    it "sets system locale using registrant's locale" do
      reg = FactoryGirl.create(:step_5_registrant, :state_id_number => "1234567890")
      reg.stub(:generate_pdf)                  # avoid messy out-of-band action in tests
      reg.stub(:deliver_confirmation_email)    # avoid messy out-of-band action in tests
      reg.stub(:enqueue_reminder_emails)       # avoid messy out-of-band action in tests

      reg.locale = 'en'
      reg.complete_registration
      assert_equal :en, I18n.locale

      reg.locale = 'es'
      reg.complete_registration
      assert_equal :es, I18n.locale
    end

    describe "background processing" do
      describe "when there is a job queue (production, staging)" do
        before(:each) do
          RockyConf.stub(:delayed_wrap_up) { true }
        end

        it "should complete immediately" do
          reg = FactoryGirl.create(:step_5_registrant, :state_id_number => "1234567890")
          reg.should_receive(:complete!)
          reg.wrap_up
        end
        it "should  enqueue emails" do
          reg = FactoryGirl.create(:step_5_registrant, :state_id_number => "1234567890")
          reg.wrap_up
          assert_match /#{reg.id}.*deliver_reminder_email/m, Delayed::Job.last.handler
        end
      end

      describe "when there is no job queue (production, staging)" do
        before(:each) do
          RockyConf.stub(:delayed_wrap_up) { false }
        end
        it "should run immediately" do
          reg = FactoryGirl.create(:step_5_registrant, :state_id_number => "1234567890")
          reg.stub(:generate_pdf)
          reg.wrap_up
          assert_match /#{reg.id}.*deliver_reminder_email/m, Delayed::Job.last.handler
        end
      end
    end
  end

  describe "deliver_confirmation_email" do
    it "should deliver an email" do
      assert_difference('ActionMailer::Base.deliveries.size', 1) do
        FactoryGirl.create(:maximal_registrant).deliver_confirmation_email
      end
    end
    it "does not send an email when address is blank" do
      assert_difference('ActionMailer::Base.deliveries.size', 0) do
        FactoryGirl.create(:maximal_registrant, :collect_email_address=>'no', :email_address=>'').deliver_confirmation_email
      end
    end
  end
  

  describe "reminder emails" do
    it "on incomplete registrant, it should be 0" do
      assert_equal 0, FactoryGirl.build(:step_4_registrant).reminders_left
    end

    it "is 0 for registrants without an email address" do
      reg = FactoryGirl.build(:maximal_registrant, 
        :collect_email_address=>'no',
        :email_address=>nil)
      reg.enqueue_reminder_emails 
      assert_equal 0, reg.reminders_left
      
    end
    it "should know how many reminder emails are left" do
      assert_equal Registrant::REMINDER_EMAILS_TO_SEND, FactoryGirl.build(:maximal_registrant, :reminders_left => Registrant::REMINDER_EMAILS_TO_SEND).reminders_left
    end

    it "should queue series of reminder emails" do
      reg = FactoryGirl.create(:maximal_registrant, :reminders_left => 0)
      assert_difference('Delayed::Job.count', 1) do
        reg.enqueue_reminder_emails
        assert_equal Registrant::REMINDER_EMAILS_TO_SEND, reg.reminders_left
      end
    end

    describe "delivery" do
      it "should send an email" do
        assert_difference('ActionMailer::Base.deliveries.size', 1) do
          reg = FactoryGirl.create(:maximal_registrant, :reminders_left => 1)
          reg.deliver_reminder_email
        end
      end
      it "should not send an email if there is no email address" do
        assert_difference('ActionMailer::Base.deliveries.size', 0) do
          reg = FactoryGirl.create(:maximal_registrant, 
            :reminders_left => 1,
            :collect_email_address=>'no')
          reg.deliver_reminder_email
        end
        
      end

      it "should not send an email if no reminders left" do
        assert_difference('ActionMailer::Base.deliveries.size'=>0) do
          reg = FactoryGirl.create(:maximal_registrant, :reminders_left => 0)
          reg.deliver_reminder_email
        end
      end

      it "should decrement reminders left" do
        reg = FactoryGirl.create(:maximal_registrant, :reminders_left => 3)
        reg.deliver_reminder_email
        assert_equal 2, reg.reload.reminders_left
      end

      it "should enqueue another reminder email" do
        assert_difference('Delayed::Job.count', 1) do
          reg = FactoryGirl.create(:maximal_registrant, :reminders_left => 3)
          reg.deliver_reminder_email
        end
      end

      it "should not enqueue another reminder email if on last email" do
        assert_difference('Delayed::Job.count'=>0) do
          reg = FactoryGirl.create(:maximal_registrant, :reminders_left => 1)
          reg.deliver_reminder_email
        end
      end
      it "should not enqueue another reminder email if no email address" do
        assert_difference('Delayed::Job.count'=>0) do
          reg = FactoryGirl.create(:maximal_registrant, 
            :reminders_left => 3,
            :collect_email_address=>'no')
          reg.deliver_reminder_email
        end
      end

      it "should log an error to Airbrake if something blows up" do
        reg = FactoryGirl.create(:maximal_registrant, :reminders_left => 1)
        reg.stub(:save) { raise 'something blows up' }

        Airbrake.should_receive(:notify).with(kind_of(Hash))
        reg.deliver_reminder_email
      end
    end
  end

  describe "shared_text" do
    describe "when complete" do
      it "says I voted" do
        reg = FactoryGirl.build(:completed_registrant)
        assert_match Regexp.new(Regexp.escape("I+just+registered+to+vote+and+you+can+too")), reg.status_text
      end
    end
    describe "when under 18" do
      it "says registering is easy" do
        reg = FactoryGirl.build(:under_18_finished_registrant)
        assert_match Regexp.new(Regexp.escape("Make+sure+you+register+to+vote")), reg.status_text
      end
    end
  end

  describe "tell-a-friend emails" do
    attr_accessor :reg
    before(:each) do
      @reg = FactoryGirl.build( :completed_registrant,
                            :name_title => "Mr.",
                            :first_name => "John", :middle_name => "Queue", :last_name => "Public",
                            :name_suffix => "Jr.",
                            :email_address => "jqp@example.com" )
    end

    describe "attributes for form fields have smart defaults" do
      it "has tell_from" do
        assert_equal "John Public", reg.tell_from
        reg.tell_from = "J. Public"
        assert_equal "J. Public", reg.tell_from
      end

      it "has tell_email" do
        assert_equal "jqp@example.com", reg.tell_email
        reg.tell_email = "jqp@gmail.com"
        assert_equal "jqp@gmail.com", reg.tell_email
      end
      
      it "sets tell_email to send_from if email is blank" do
        reg.collect_email_address='no'
        assert_equal reg.tell_email, reg.email_address_to_send_from
      end
      

      it "has tell_subject" do
        assert_equal "I just registered to vote and you should too", reg.tell_subject
        reg.tell_subject = "This is super cool"
        assert_equal "This is super cool", reg.tell_subject
      end

      it "has tell_subject default for under 18" do
        reg = FactoryGirl.build(:under_18_finished_registrant)
        assert_equal "Register to vote!", reg.tell_subject
        reg.tell_subject = "This is super cool"
        assert_equal "This is super cool", reg.tell_subject
      end
    end

    describe "enqueue emails when registrant has valid tell-a-friend params" do
      before(:each) do
        @tell_params = {
          :telling_friends => true,
          :tell_from => "Bob Dobbs",
          :tell_email => "bob@example.com",
          :tell_recipients => "arnold@example.com, obo@example.com, slack@example.com",
          :tell_subject => "Register to vote the easy way",
          :tell_message => "I registered to vote and you can too."
        }
      end

      it "enqueues email when valid" do
        reg.attributes = @tell_params
        assert_difference "Delayed::Job.count" do
          assert reg.valid?
        end
      end
      

      it "does not enqueue when invalid" do
        reg.attributes = @tell_params.merge(:tell_recipients => "")
        assert_difference "Delayed::Job.count", 0 do
          assert reg.invalid?
        end
      end

      # Disabled until spammers can be stopped
      # it "sends one email per recipient" do
      #   mock(Notifier).deliver_tell_friends(anything).times(3)
      #   Registrant.deliver_tell_friends_emails(@tell_params)
      # end
    end
  end

  describe 'completed_at' do
    it 'should return the last modification date for completed_at when completed' do
      reg = FactoryGirl.create(:maximal_registrant)
      reg.completed_at.should == reg.updated_at
    end

    specify { FactoryGirl.create(:step_1_registrant).completed_at.should be_nil }
  end

  describe 'extended_status' do
    it 'should be complete when complete' do
      reg = FactoryGirl.build(:maximal_registrant)
      reg.extended_status.should == 'complete'
    end

    it 'should be marked as abandoned if incomplete' do
      reg = FactoryGirl.build(:step_1_registrant)
      reg.extended_status.should == 'abandoned after step 1'
    end

    it 'should report just abandoned otherwise' do
      reg = Registrant.new
      reg.extended_status.should == 'abandoned'
    end
  end

  def assert_attribute_invalid_with(model, attributes)
    reg = FactoryGirl.build(model, attributes)
    reg.invalid?
    assert attributes.keys.any? { |attr_name| reg.errors[attr_name] }
  end

  def assert_attribute_valid_with(model, attributes)
    reg = FactoryGirl.build(model, attributes)
    assert reg.valid?
  end
end
