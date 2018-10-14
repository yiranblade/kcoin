require 'jwt'
require './controllers/base'
require './helpers/email_helpers'
require 'digest/sha1'

class UserController < BaseController
  helpers EmailHelpers
  helpers UserAppHelpers
  helpers HistoryHelpers
  KCOIN = 'kcoin'

  before do
    set_current_user
  end

  # user profile page
  get '/' do
    redirect '/' unless authenticated?
    user_id = params[:user_id] ? params[:user_id] : current_user.id
    user_detail = find_user(user_id)
    # fetch data from chaincode
    token_history = get_kcoin_history(user_detail.eth_account)
    project_history = get_project_list_history(user_id)

    haml :user, locals: {user_detail: user_detail,
                         token_history: token_history,
                         project_list: project_history}
  end

  get '/login' do
    session[:redirect_uri] = request.params['redirect_uri'] ||= '/'
    haml :login, layout: false
  end

  get '/join' do
    session[:redirect_uri] = request.params['redirect_uri'] ||= '/'
    haml :join, layout: false
  end

  post '/login' do
    email = params[:email].to_s
    pwd = Digest::SHA1.hexdigest(params[:password])
    @user = nil
    @user = if email.include? '@'
              User.first(email: email, password_digest: pwd)
            else
              User.first(login: email, password_digest: pwd)
            end
    if @user
      if @user.password_digest == pwd
        session[:user_id] = @user.id
        redirect session[:redirect_uri] ||= '/'
      end
    end
  end

  # Registered user
  post '/join' do
    login_value = params[:login]
    if login_value.empty?
      login_value = params[:email].split('@')[0]
    end

    DB.transaction do
      user = User.new(login: login_value,
                      name: params[:name],
                      password_digest: Digest::SHA1.hexdigest(params[:password]),
                      eth_account: Digest::SHA1.hexdigest(params[:email]),
                      email: params[:email],
                      avatar_url: nil,
                      activated: true,
                      creawted_at: Time.now,
                      updateed_at: Time.now,
                      last_login_at: Time.now)

      user.save
      UserEmail.insert(user_id: user.id,
                       email: params[:email],
                       verified: false,
                       created_at: Time.now)
    end

    session[:user_id] = user.id
    send_register_email(user)
    redirect session[:redirect_uri] ||= '/'
  end

  # Verify email is registered
  post '/validate/email' do
    valid = email_not_registered params[:email]
    {
        flag: valid
    }.to_json
  end


  # Verify user is existed
  post '/validate/user' do
    param = params[:email].to_s
    pwd = Digest::SHA1.hexdigest(params[:password])
    user = if param.include? '@'
             User.first(email: param, password_digest: pwd)
           else
             User.first(login: param, password_digest: pwd)
           end
    user ? {flag: true}.to_json : {flag: false}.to_json
  end

  get '/edit_page' do
    user_detail = find_user(params[:user_id])
    haml :user_edit, locals: {user_detail: user_detail}
  end

  post '/update_user' do
    user = find_user(params[:user_id])
    user.update(name: params[:name], brief: params[:brief])
    redirect '/user'
  end
end
