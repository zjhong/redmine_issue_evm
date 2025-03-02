# lib/hourly_rates_hook_listener.rb
class HourlyRatesHookListener < Redmine::Hook::ViewListener
    render_on :view_users_show_contextual, partial: 'hourly_rates/user_rates_link'
  end