class CreateHourlyRates < ActiveRecord::Migration[4.2]
  def change
    create_table :hourly_rates do |t|
      t.integer :user_id, null: false         # 关联用户ID
      t.float :rate, null: false              # 时薪
      t.date :effective_date, null: false     # 生效日期
      t.date :end_date                        # 结束日期(为空表示当前有效)
      t.integer :project_id                   # 项目ID(为空表示全局)
      t.integer :created_by                   # 创建人
      t.integer :updated_by                   # 更新人
      t.datetime :created_on                  # 创建时间
      t.datetime :updated_on                  # 更新时间
      t.text :comment                         # 备注说明
    end
    
    add_index :hourly_rates, [:user_id, :effective_date, :project_id], 
              name: 'index_hourly_rates_on_user_date_project', unique: true
  end
end