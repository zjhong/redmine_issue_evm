# EVM Cache Invalidator
# This module provides methods to invalidate EVM caches when related data changes
module EvmCacheInvalidator
  # Invalidate EVM cache for a project
  def self.invalidate_project_cache(project_id)
    # Find all cache keys that match the project pattern
    cache_keys = Rails.cache.instance_variable_get(:@data).try(:keys) || []
    project_cache_keys = cache_keys.select { |key| key.to_s.include?("evm_project_#{project_id}") || key.to_s.include?("evm_data_#{project_id}") }
    
    # Delete each matching cache key
    project_cache_keys.each do |key|
      Rails.cache.delete(key)
    end
  end
  
  # Invalidate EVM cache for all projects
  def self.invalidate_all_caches
    # Find all cache keys that match the EVM pattern
    cache_keys = Rails.cache.instance_variable_get(:@data).try(:keys) || []
    evm_cache_keys = cache_keys.select { |key| key.to_s.include?("evm_project_") || key.to_s.include?("evm_data_") }
    
    # Delete each matching cache key
    evm_cache_keys.each do |key|
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
        EvmCacheInvalidator.invalidate_project_cache(self.project_id)
      end
    end
  end
end

# Include the hooks in the respective models
Issue.send(:include, IssueHook)
TimeEntry.send(:include, TimeEntryHook)
Evmbaseline.send(:include, BaselineHook) 