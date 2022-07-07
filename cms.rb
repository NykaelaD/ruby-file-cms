require "sinatra"
require "sinatra/reloader"
require "tilt/erubis" 
require "redcarpet"
require "yaml"
require "bcrypt"

configure do 
  enable :sessions
  set :session_secret, 'secret'
end 

helpers do 
  def render_markdown(text)
    markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
    markdown.render(text)
  end 
  
  def load_content(file_path)
    content = File.read(file_path)
    case File.extname(file_path) 
    when ".txt"
      headers["Content-Type"] = "text/plain"
      content
    when ".md"
      erb render_markdown(content)
    end 
  end 
end 

def data_path
  if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/data", __FILE__)
  else
    File.expand_path("../data", __FILE__)
  end
end

def valid_name(name)
  (1..100).cover?(name.length)
end 

def user_signed_in?
  !!session[:username]
end 

def redirect_signed_out_user
  unless user_signed_in?
    session[:message] = "You must be signed in to do that."
    redirect "/"
  end 
end 

def load_users
  credentials_path = if ENV["RACK_ENV"] == "test"
      File.expand_path("../test/users.yaml", __FILE__)
    else
      File.expand_path("../users.yaml", __FILE__)
    end
  YAML.load_file(credentials_path)
end 

def valid_user?(username, password)
  users = load_users
  if users.key?(username)
    bcrypt_password = BCrypt::Password.new(users[username]) 
    bcrypt_password == password
  else 
    false
  end 
end

get "/" do
  pattern = File.join(data_path, "*")
  @files = Dir.glob(pattern).map do |path|
    File.basename(path)
  end
  
  erb :index, layout: :layout
end 

get "/signin" do 
  erb :sign_in, layout: :layout
end 

post "/signin" do 
  if valid_user?(params[:username], params[:password])
    session[:username] = params[:username] 
    session[:message] = "Welcome!"
    redirect "/"
  else 
    session[:message] = "Invalid Credentials"
    status 422
    erb :sign_in, layout: :layout
  end 
end 

post "/signout" do 
  session.delete(:username)
  session[:message] = "You have been signed out."
  redirect "/"
end 

# new document form
get "/new" do
  redirect_signed_out_user
  
  erb :new_file, layout: :layout
end 

# submit a new document
post "/create" do 
  redirect_signed_out_user
  
  filename = params[:filename].to_s
  
  if filename.size == 0 
    session[:message] = "A name is required"
    status 422
    erb :new_file, layout: :layout
  else 
    file_path = File.join(data_path, filename)
    
    File.write(file_path, "")
    session[:message] = "#{params[:filename]} was created."
    
    redirect "/"
  end 
end 

# view document
get "/:filename" do
  redirect_signed_out_user
  
  file_path = File.join(data_path, params[:filename])
  
  if File.exist?(file_path)
    load_content(file_path)
  else 
    session[:message] = "#{params[:filename]} does not exist."
    redirect "/"
  end 
end 

# edit document page 
get "/:filename/edit" do 
  redirect_signed_out_user
  
  file_path = File.join(data_path, params[:filename])
  @file_name = params[:filename]
  @content = File.read(file_path)
  
  erb :edit_file, layout: :layout
end 

# delete a document 
post "/:filename/delete" do 
  redirect_signed_out_user
  
  @filename = params[:filename]
  file_path = File.join(data_path, @filename)
  File.delete(file_path)
  
  session[:message] = "#{@filename} has been deleted"
  redirect "/"
end 

# make changes to a document 
post "/:filename" do
  redirect_signed_out_user
  
  file_path = File.join(data_path, params[:filename])

  File.write(file_path, params[:content])

  session[:message] = "#{params[:filename]} has been updated."
  redirect "/"
end 


