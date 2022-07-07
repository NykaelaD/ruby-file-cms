ENV["RACK_ENV"] = "test"

require "fileutils"

require "minitest/autorun"
require "rack/test"
require "yaml"
require "bcrypt"

require_relative "../cms"

class CMSTest < Minitest::Test
  include Rack::Test::Methods

  def app 
    Sinatra::Application
  end 

  def setup
	FileUtils.mkdir_p(data_path)
  end 

  def teardown
	FileUtils.rm_rf(data_path)
  end 
	
  def create_document(name, content="")
    File.open(File.join(data_path, name), "w") do |file|
	  file.write(content)
    end 
  end
	
  def session
    last_request.env["rack.session"]
  end 
	
  def admin_session
    { "rack.session" => { username: "admin" } }
  end 
	
  def test_index 
    create_document "about.md"
    create_document "changes.txt"
	
    get "/"
  
    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "about.md"
    assert_includes last_response.body, "changes.txt"
  end 

  def test_view_documents
    create_document "history.txt", "history of ruby"
	
    get "/history.txt", {}, admin_session
    assert_equal 200, last_response.status
    assert_equal "text/plain", last_response["Content-Type"]
    assert_includes last_response.body, "history of ruby"
  end
  
  def test_view_documents_signed_out
	create_document "history.txt"
	
	get "/history.txt"
	assert_equal 302, last_response.status
	assert_equal "You must be signed in to do that.", session[:message]
  end 
	
  def test_invalid_page
	get "/not_a_file.txt", {}, admin_session
	
	assert_equal 302, last_response.status # user was redirected 
	assert_equal "not_a_file.txt does not exist.", session[:message]
  end 
	
  def test_view_markdown_document  
	create_document "about.md", "#Ruby is..."
	
	get "/about.md", {}, admin_session
    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "<h1>Ruby is...</h1>"
  end 
	
  def test_edit_document
	create_document "changes.txt"
	
	get "/changes.txt/edit", {}, admin_session
	assert_equal 200, last_response.status
	assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "Edit content of" # takes you to correct page 
	
	post "/changes.txt", content: "new content" # properly redirected
	assert_equal 302, last_response.status
	assert_equal "changes.txt has been updated.", session[:message]
	
	get "/changes.txt"
	assert_equal 200, last_response.status
	assert_includes last_response.body, "new content"
  end 
  
  def test_edit_document_signed_out
  	create_document "changes.txt"

    get "/changes.txt/edit"

    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:message]
  end 
	
  def test_create_new_document 
	get "/new", {}, admin_session
	
	assert_equal 200, last_response.status 
	assert_includes last_response.body, "<input"
	assert_includes last_response.body, %q(<button type="submit")
	
	post "/create", filename: "new_doc.txt"
	assert_equal 302, last_response.status
	assert_equal "new_doc.txt was created.", session[:message]
	
	get "/"
	assert_includes last_response.body, "new_doc.txt"
  end 
  
  def create_new_document_signed_out
    get "/new"

    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:message]
    
    post "/new"

    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:message]
  end 
	
  def test_create_new_doc_without_file_name
	post "/create", {filename: ""}, admin_session
	assert_equal 422, last_response.status
	assert_includes last_response.body, "A name is required"
  end
	
  def test_delete_file
	create_document "changes.txt"
	
	post "/changes.txt/delete", {}, admin_session
	assert_equal 302, last_response.status 
	assert_equal "changes.txt has been deleted", session[:message]

	get "/"
	refute_includes last_response.body, %q(href="/changes.txt")
  end 
  
  def test_delete_file_signed_out
  	create_document "changes.txt"
	
	post "/changes.txt/delete"
	assert_equal 302, last_response.status 
	assert_equal "You must be signed in to do that.", session[:message]
  end
	
  def test_sign_in
	get "/signin"
	assert_equal 200, last_response.status
	
	post "signin", username: "admin", password: "secret"
	assert_equal 302, last_response.status
	assert_equal "Welcome!", session[:message]
	assert_equal "admin", session[:username]
	
	get last_response["Location"]
	assert_includes last_response.body, "Signed in as admin"
  end 
	
  def test_sign_in_wrong_credentials
	post "/signin", username: "invalid", password: "invalid"
	assert_equal 422, last_response.status
	assert_nil session[:username]
	assert_includes last_response.body, "Invalid Credentials"
  end 
	
  def test_sign_out
	get "/", {}, {"rack.session" => {username: "admin" } }
	assert_includes last_response.body, "Signed in as admin"
	post "/signout"
	assert_equal "You have been signed out.", session[:message]
	
	get last_response["Location"]
	assert_nil session[:username]
	assert_includes last_response.body, "Sign In"
  end 
end 