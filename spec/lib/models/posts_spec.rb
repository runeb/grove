require 'spec_helper'

describe Post do
  it "can generate a path" do
    p = Post.new(:realm => "area51", :box => "vaktmesterkontoret", :collection => "forum1", :oid => "name")
    p.path.should eq "area51.vaktmesterkontoret.forum1"
  end

  it "can genereate an uid" do
    p = Post.new(:realm => "area51", :box => "vaktmesterkontoret", :collection => "forum1", :oid => "name")
    p.uid.should eq "post:area51.vaktmesterkontoret.forum1$name"
  end

  it "can retrieve one by uid" do
    Post.create!(:realm => "area51", :box => "vaktmesterkontoret", :collection => "forum1", :oid => "1", :document => "1")
    Post.create!(:realm => "area51", :box => "vaktmesterkontoret", :collection => "forum1", :oid => "2", :document => "2")
    Post.create!(:realm => "area51", :box => "vaktmesterkontoret", :collection => "forum2", :oid => "1", :document => "3")
    Post.find_by_uid("post:area51.vaktmesterkontoret.forum1$1").document.should eq '1'
    Post.find_by_uid("post:area51.vaktmesterkontoret.forum1$2").document.should eq '2'
    Post.find_by_uid("post:area51.vaktmesterkontoret.forum2$1").document.should eq '3'
    Post.find_by_uid("post:area51.vaktmesterkontoret.forum2$2").should be_nil
  end

  it "can assign realm, box, collection and oid by assigning uid" do
    p = Post.new(:uid => "post:area51.vaktmesterkontoret.forum1$name")
    p.realm.should eq "area51"
    p.box.should eq "vaktmesterkontoret"
    p.collection.should eq "forum1"
    p.oid.should eq "name"
  end

  it "can retrieve a collection of posts with a wildcard uid" do
    Post.create!(:uid => "post:area51.vaktemsterkontoret.forum1$doc1", :document => "1")
    Post.create!(:uid => "post:area51.vaktemsterkontoret.forum1$doc2", :document => "2")
    Post.create!(:uid => "post:area51.vaktemsterkontoret.forum1$doc3", :document => "3")
    Post.create!(:uid => "post:area51.vaktemsterkontoret.forum2$doc1", :document => "4")
    Post.create!(:uid => "post:area52.vaktemsterkontoret.forum2$doc1", :document => "5")
    Post.by_wildcard_uid("post:*").map(&:document).sort.should eq ['1', '2', '3', '4', '5']
    Post.by_wildcard_uid("post:area51.*").map(&:document).sort.should eq ['1', '2', '3', '4']
    Post.by_wildcard_uid("post:area51.vaktemsterkontoret.forum1").map(&:document).sort.should eq ['1', '2', '3']
    Post.by_wildcard_uid("post:area51.vaktemsterkontoret.forum2").map(&:document).sort.should eq ['4']
    Post.by_wildcard_uid("post:*$doc1").map(&:document).sort.should eq ['1', '4', '5']
  end

  it "has a fancy method to get a lot of posts with readthrough caching (memcached)" do
    doc1 = Post.create!(:uid => "post:area51.vaktemsterkontoret.forum1$doc1", :document => "1")
    Post.create!(:uid => "post:area51.vaktemsterkontoret.forum1$doc2", :document => "2")
    posts = Post.cached_find_all_by_uid(["post:area51.vaktemsterkontoret.forum1$doc1", "post:area51.vaktemsterkontoret.forum1$doc2"])
    posts.first.document.should eq '1'
    # Have a look in the cache to verify that the documents got there
    post = JSON.parse($memcached.get("post:area51.vaktemsterkontoret.forum1$doc1"))
    post['document'].should eq '1'
    # Verify that the order matches the request
    posts = Post.cached_find_all_by_uid(["post:area51.vaktemsterkontoret.forum1$doc2", "post:area51.vaktemsterkontoret.forum1$doc1"])
    posts.first.document.should eq '2'
    # Change the cached document to verify that it actually reads through the cache
    post['document'] = "sentinel"    
    $memcached.set("post:area51.vaktemsterkontoret.forum1$doc1", post.to_json)
    posts = Post.cached_find_all_by_uid(["post:area51.vaktemsterkontoret.forum1$doc1", "post:area51.vaktemsterkontoret.forum1$doc2"])
    posts.first.document.should eq 'sentinel'
    # Delete one of the cached documents to verify that the finder can perform with only partial cache hits
    $memcached.delete("post:area51.vaktemsterkontoret.forum1$doc1")
    posts = Post.cached_find_all_by_uid(["post:area51.vaktemsterkontoret.forum1$doc1", "post:area51.vaktemsterkontoret.forum1$doc2"])
    posts.first.document.should eq '1'
    # Update one to verify that the cache is invalidated
    doc1.document = "watchdog"
    doc1.save!
    posts = Post.cached_find_all_by_uid(["post:area51.vaktemsterkontoret.forum1$doc1", "post:area51.vaktemsterkontoret.forum1$doc2"])
    posts.first.document.should eq 'watchdog'
  end

  it "knows how to handle non-existant posts when using cached_find_all_by_uid" do
    posts = Post.cached_find_all_by_uid(["post:out.of.this$world"])    
    posts.should eq [nil]
  end

  it "has a virtual tags property that is actually stored as a tsvector in tags_vector" do
    p = Post.new
    p.tags.should eq []
    p.tags = ['bing', 'Bang!']
    p.tags_vector.should eq "'bing' 'bang'"
    p.tags.should eq ['bing', 'bang']
    p.tags = "bing, padunk"
    p.tags.should eq ['bing', 'padunk']
  end

  it "can scope posts by tag" do
    Post.create!(:uid => "post:a.b.c$doc1", :tags => ["france", "paris"], :document => '1')
    Post.create!(:uid => "post:a.b.c$doc2", :tags => ["capitals", "paris"], :document => '2')
    Post.create!(:uid => "post:a.b.c$doc3", :tags => ["france", "lyon"], :document => '3')
    Post.with_tags("paris").all.map(&:document).sort.should eq ['1', '2']
    Post.with_tags("france").all.map(&:document).sort.should eq ['1', '3']
    Post.with_tags(["france", "paris"]).all.map(&:document).sort.should eq ['1']
  end

end