# EVM Cache Invalidator
# This module provides methods to invalidate EVM caches when related data changes
module EvmCacheInvalidator
  # Invalidate EVM cache for a project
  def self.invalidate_project_cache(project_id)
    # Find all cache keys that match the project pattern
    cache_keys = Rails.cache.instance_variable_get(:@data).try(:keys) || []
    project_cache_keys = cache_keys.select do |key| 
      key_str = key.to_s
      key_str.include?("evm_project_#{project_id}") || 
      key_str.include?("evm_data_#{project_id}_")
    end
    
    # Log the keys being invalidated
    Rails.logger.info("Invalidating project cache keys: #{project_cache_keys.join(', ')}")
    
    # Delete each matching cache key
    project_cache_keys.each do |key|
      Rails.logger.info("Deleting cache key: #{key}")
      Rails.cache.delete(key)
    end
    
    # Also invalidate all projects cache since it contains data for this project
    invalidate_all_projects_cache
    
    # Also invalidate EVM members cache since it might contain data for this project
    invalidate_evm_members_cache
  end
  
  # Invalidate EVM cache for all projects
  def self.invalidate_all_caches
    # Find all cache keys that match the EVM pattern
    cache_keys = Rails.cache.instance_variable_get(:@data).try(:keys) || []
    evm_cache_keys = cache_keys.select do |key| 
      key_str = key.to_s
      key_str.include?("evm_project_") || 
      key_str.include?("evm_data_") || 
      key_str.include?("all_projects_evm_") || 
      key_str.include?("evm_members_")
    end
    
    # Log the keys being invalidated
    Rails.logger.info("Invalidating all EVM cache keys: #{evm_cache_keys.join(', ')}")
    
    # Delete each matching cache key
    evm_cache_keys.each do |key|
      Rails.logger.info("Deleting cache key: #{key}")
      Rails.cache.delete(key)
    end
  end
  
  # Invalidate the all projects EVM cache
  def self.invalidate_all_projects_cache
    # Find all cache keys that match the all projects EVM pattern
    cache_keys = Rails.cache.instance_variable_get(:@data).try(:keys) || []
    all_projects_cache_keys = cache_keys.select { |key| key.to_s.include?("all_projects_evm_") }
    
    # Log the keys being invalidated
    Rails.logger.info("Invalidating all projects EVM cache keys: #{all_projects_cache_keys.join(', ')}")
    
    # Delete each matching cache key
    all_projects_cache_keys.each do |key|
      Rails.logger.info("Deleting cache key: #{key}")
      Rails.cache.delete(key)
    end
  end
  
  # Invalidate the EVM members cache
  def self.invalidate_evm_members_cache
    # Find all cache keys that match the EVM members pattern
    cache_keys = Rails.cache.instance_variable_get(:@data).try(:keys) || []
    evm_members_cache_keys = cache_keys.select { |key| key.to_s.include?("evm_members_") }
    
    # Log the keys being invalidated
    Rails.logger.info("Invalidating EVM members cache keys: #{evm_members_cache_keys.join(', ')}")
    
    # Delete each matching cache key
    evm_members_cache_keys.each do |key|
      Rails.logger.info("Deleting cache key: #{key}")
      Rails.cache.delete(key)
    end
  end
  
  # Find the project ID from an issue
  def self.find_project_id_from_issue(issue)
    issue.project_id
  end
  
  # Find the project ID from a time entry
  def self.find_project_id_from_time_entry(time_entry)
    if time_entry.issue
      time_entry.issue.project_id
    else
      time_entry.project_id
    end
  end
end

# Add hooks to invalidate cache when issues are created, updated, or deleted
module IssueHook
  def self.included(base)
    base.class_eval do
      after_create :invalidate_evm_cache
      after_update :invalidate_evm_cache
      after_destroy :invalidate_evm_cache
      
      def invalidate_evm_cache
        project_id = EvmCacheInvalidator.find_project_id_from_issue(self)
        Rails.logger.info("Invalidating EVM cache for issue #{self.id} in project #{project_id}")
        EvmCacheInvalidator.invalidate_project_cache(project_id)
      end
    end
  end
end

# Add hooks to invalidate cache when time entries are created, updated, or deleted
module TimeEntryHook
  def self.included(base)
    base.class_eval do
      after_create :invalidate_evm_cache
      after_update :invalidate_evm_cache
      after_destroy :invalidate_evm_cache
      
      def invalidate_evm_cache
        project_id = EvmCacheInvalidator.find_project_id_from_time_entry(self)
        Rails.logger.info("Invalidating EVM cache for time entry #{self.id} in project #{project_id}")
        EvmCacheInvalidator.invalidate_project_cache(project_id)
      end
    end
  end
end

# Add hooks to invalidate cache when baselines are created, updated, or deleted
module BaselineHook
  def self.included(base)
    base.class_eval do
      after_create :invalidate_evm_cache
      after_update :invalidate_evm_cache
      after_destroy :invalidate_evm_cache
      
      def invalidate_evm_cache
        Rails.logger.info("Invalidating EVM cache for baseline #{self.id} in project #{self.project_id}")
        EvmCacheInvalidator.invalidate_project_cache(self.project_id)
      end
    end
  end
end

# Include the hooks in the respective models
Issue.send(:include, IssueHook)
TimeEntry.send(:include, TimeEntryHook)
Evmbaseline.send(:include, BaselineHook) 