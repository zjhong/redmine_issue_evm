# routing
Rails.application.routes.draw do
  # 项目级资源
  resources :projects do
    resources :evms, :evmbaselines, :evmsettings, :evmassignees, :evmparentissues, :evmversions, :evmtrackers, :evmexcludes,
              :evmbaselinediffdetails, :evmreports
  end
  
  # 全局EVM路由
  get 'global_evm', to: 'evms#global'
  get 'global_evm/baselines', to: 'evmbaselines#global_index'
  post 'global_evm/baselines', to: 'evmbaselines#create_global'
  
  # 小时费率管理
  resources :hourly_rates
  get 'users/:user_id/hourly_rates', to: 'hourly_rates#user_rates', as: 'user_hourly_rates'
end