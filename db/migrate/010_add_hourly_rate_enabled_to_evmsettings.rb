class AddHourlyRateEnabledToEvmsettings < ActiveRecord::Migration[4.2]
  def change
    add_column :evmsettings, :hourly_rate_enabled, :boolean, default: false
  end
end 