require 'pebblebed'
require_relative 'models/post'

class RiverNotifications < ActiveRecord::Observer

  observe Post

  def self.river
    @river ||= Pebbles::River::River.new
  end

  # ActiveRecord 4 specific method transaction_include_any_action?
  #
  # There is no way of specifying a condition on a hook in an observer, like:
  # after_commit, on: :create
  # So we need to check the transaction here in the observer
  def is?(object, action)
    if !object.respond_to?(:transaction_include_any_action?, true)
      raise 'ActiveRecord 4 specific method \'transaction_include_any_action?\' not available, please fix'
    end
    object.send(:transaction_include_any_action?, [action])
  end
  private :is?

  def after_commit(object)
    if object.is_a?(Post) && is?(object, :create)
      prepare_for_publish(object, :create)
    end
  end

  def after_update(object)
    if object.is_a?(Post)
      if object.deleted?
        prepare_for_publish(object, :delete, :soft_deleted => true)
      else
        prepare_for_publish(object, :update)
      end
    end
  end

  def after_destroy(object)
    if object.is_a?(Post)
      prepare_for_publish(object, :delete)
    end
  end

  def publish!(params)
    self.class.river.publish(params)
  end

  private

    def prepare_for_publish(post, event, options = {})
      post.paths.each do |path|
        params = {
          :uid => "#{post.klass}:#{path}$#{post.id}",
          :event => event,
          :attributes => post.attributes_for_export
        }
        params[:changed_attributes] = post.changes if event == :update
        params[:soft_deleted] = true if options[:soft_deleted]
        publish!(params)
      end
    end

end
