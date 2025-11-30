class GreetingsController < ApplicationController
  def hello
    render json: { message: "Olá do Rails!" }
  end
end
