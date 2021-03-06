require 'spec_helper'

describe Readmark do
  it "counts new posts in own and descendant paths" do
    r = Readmark.create!(:path => "a.b.c")
    Readmark.post_added("a.b", 1)
    Readmark.post_added("a.b.c", 2)
    Readmark.post_added("a.b.c.d", 3)
    r.reload
    r.unread_count.should eq 2
  end

  it "uncounts deleted posts when they are among the unread ones" do
    r = Readmark.create!(:path => "a.b.c", :unread_count => 2, :post_id => 5)
    Readmark.post_removed("a.b.c", 2)
    Readmark.post_removed("a.b.c", 3)
    Readmark.post_removed("a.b.c", 5)
    Readmark.post_removed("a.b.c", 6)
    r.reload
    r.unread_count.should eq 1
  end

  it "recounts unread posts correctly" do
    p1 = Post.create!(:canonical_path => "a.b.c")
    p2 = Post.create!(:canonical_path => "a.b.c.d")
    p3 = Post.create!(:canonical_path => "a.b.c.d")
    p4 = Post.create!(:canonical_path => "a.b.c.d.e")
    r = Readmark.create!(:path => "a.b.c.d", :post_id => p2.id)
    r.recount!    
    r.unread_count.should eq 2
  end

  it "gets updated autmatically as posts are added" do
    r1 = Readmark.create!(:path => "a.b")
    r2 = Readmark.create!(:path => "a.c")
    p = Post.create!(:canonical_path => "a.b")
    r1.reload
    r1.unread_count.should eq 1
    r2.unread_count.should eq 0
    p.paths |= ["a.c.d"]
    p.save!
    r2.reload
    r2.unread_count.should eq 1
    p.paths = []
    p.save!
    r2.reload
    r2.unread_count.should eq 0
  end

  it "can set a readmark and update readmark count accordingly" do
    posts = (1..10).map { Post.create!(:canonical_path => "a.b.c") }
    readmark = Readmark.set!(1, "a.b", posts[-2].id)
    readmark.unread_count.should eq 1
    readmark = Readmark.set!(1, "a.b", posts[-5].id)
    readmark.unread_count.should eq 4
    Readmark.count.should eq 1
  end

  it "gets notified when a post is deleted or undeleted" do
    r = Readmark.create!(:path => "a.b")
    p = Post.create!(:canonical_path => "a.b.c")
    r.reload
    r.unread_count.should eq 1
    p.deleted = true
    p.save!
    r.reload
    r.unread_count.should eq 0
    p.deleted = false
    p.save!
    r.reload
    r.unread_count.should eq 1
  end

end
