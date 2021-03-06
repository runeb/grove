require 'spec_helper'

describe RiverNotifications do

  before(:each) do
    ActiveRecord::Base.add_observer RiverNotifications.instance
  end

  after(:each) do
    ActiveRecord::Base.observers = []
  end

  describe "create" do

    it "publishes the post with no changed_attributes entry" do
      RiverNotifications.any_instance.should_receive(:publish!) do |arg|
        arg[:event].should eq :create
        arg[:uid].should_not be nil
        arg[:attributes].should_not be nil
        arg[:attributes]['version'].should eq 1
        arg[:changed_attributes].should be nil
      end
      Post.create!(:canonical_path => 'this.that')
    end

  end

  describe "update" do

    it "publishes the post together with changed_attributes" do
      ActiveRecord::Base.observers.disable :all
      p = Post.create!(:canonical_path => 'this.that', :published => false, :document => {:text => 'blipp'})
      p.published = true
      p.document = {:text => 'jumped over the lazy dog'}
      ActiveRecord::Base.observers.enable :all
      RiverNotifications.any_instance.should_receive(:publish!) do |arg|
        arg[:event].should eq :update
        arg[:uid].should_not be nil
        arg[:attributes].should_not be nil
        arg[:attributes]['version'].should eq 2
        arg[:changed_attributes][:published].should eq [false, true]
        arg[:changed_attributes][:document].should eq [
          {'text' => "blipp"},
          {'text' => "jumped over the lazy dog"}
        ]
      end
      p.save!
    end

    it "publishes the post together with changed_attributes even if a serialized field has been updated" do
      ActiveRecord::Base.observers.disable :all
      p = Post.create!(:canonical_path => 'this.that', :published => false, :document => {:text => 'blipp'})
      p.document = p.document.merge(:text => 'jumped over the lazy dog')
      ActiveRecord::Base.observers.enable :all
      RiverNotifications.any_instance.should_receive(:publish!) do |arg|
        arg[:event].should eq :update
        arg[:uid].should_not be nil
        arg[:attributes].should_not be nil
        arg[:changed_attributes][:document].should eq [
          {'text' => "blipp"},
          {'text' => "jumped over the lazy dog"}
        ]
      end
      p.save!
    end

  end

  describe "delete" do

    it "creates a delete event with the soft delete flag set" do
      ActiveRecord::Base.observers.disable :all
      p = Post.create!(:canonical_path => 'this.that', :document => {:text => 'blipp'})
      ActiveRecord::Base.observers.enable :all
      RiverNotifications.any_instance.should_receive(:publish!) do |arg|
        arg[:event].should eq :delete
        arg[:soft_deleted].should be true
      end
      p.deleted = true
      p.save!
    end

  end

end
