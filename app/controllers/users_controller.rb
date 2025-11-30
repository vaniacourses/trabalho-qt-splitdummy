class UsersController < ApplicationController
  before_action :authenticate_user!, only: [:index]

  # GET /users?search=termo
  def index
    users = User.all
    if params[:search].present?
      search_term = "%#{params[:search]}%"
      users = users.where("name LIKE ? OR email LIKE ?", search_term, search_term)
    end
    # Limita a 50 resultados para performance
    users = users.limit(50)
    render json: users.as_json(only: [:id, :name, :email])
  end

  def create
    user = User.new(user_params)
    if user.save
      session[:user_id] = user.id
      render json: { status: :created, user: user }
    else
      render json: { status: 422, errors: user.errors.full_messages }
    end
  end

  def show
    user = User.find_by(id: params[:id])
    if user
      render json: { user: user }
    else
      render json: { status: 404, message: 'Usuário não encontrado.' }
    end
  end

  private

  def user_params
    params.require(:user).permit(:name, :email, :password, :password_confirmation, :default_currency, :profile_picture_url)
  end
end
