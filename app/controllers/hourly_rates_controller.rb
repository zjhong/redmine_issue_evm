# app/controllers/hourly_rates_controller.rb
class HourlyRatesController < ApplicationController
    before_action :require_admin, only: [:index, :new, :create, :edit, :update, :destroy]
    before_action :find_hourly_rate, only: [:edit, :update, :destroy]
    before_action :find_user, only: [:user_rates]
    
    def index
      @users = User.active.sorted
      @rates_by_user = {}
      
      @users.each do |user|
        @rates_by_user[user.id] = HourlyRate.for_user(user.id)
          .order(effective_date: :desc, project_id: :asc)
      end
    end
    
    def new
      @hourly_rate = HourlyRate.new
      @hourly_rate.effective_date = Date.today
      @users = User.active.sorted
      @projects = Project.visible.sorted
    end
    
    def create
      @hourly_rate = HourlyRate.new(hourly_rate_params)
      @hourly_rate.created_by = User.current.id
      @hourly_rate.updated_by = User.current.id
      @hourly_rate.created_on = Time.now
      @hourly_rate.updated_on = Time.now
      
      if @hourly_rate.save
        flash[:notice] = l(:notice_successful_create)
        redirect_to hourly_rates_path
      else
        @users = User.active.sorted
        @projects = Project.visible.sorted
        render :new
      end
    end
    
    def edit
      @users = User.active.sorted
      @projects = Project.visible.sorted
    end
    
    def update
      @hourly_rate.assign_attributes(hourly_rate_params)
      @hourly_rate.updated_by = User.current.id
      @hourly_rate.updated_on = Time.now
      
      if @hourly_rate.save
        flash[:notice] = l(:notice_successful_update)
        redirect_to hourly_rates_path
      else
        @users = User.active.sorted
        @projects = Project.visible.sorted
        render :edit
      end
    end
    
    def destroy
      @hourly_rate.destroy
      flash[:notice] = l(:notice_successful_delete)
      redirect_to hourly_rates_path
    end
    
    def user_rates
      @rates = HourlyRate.for_user(@user.id)
        .order(effective_date: :desc, project_id: :asc)
    end
    
    private
    
    def find_hourly_rate
      @hourly_rate = HourlyRate.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      render_404
    end
    
    def find_user
      @user = User.find(params[:user_id])
    rescue ActiveRecord::RecordNotFound
      render_404
    end
    
    def hourly_rate_params
      params.require(:hourly_rate).permit(:user_id, :rate, :effective_date, :end_date, :project_id, :comment)
    end
  end