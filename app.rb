require 'sinatra'
require 'slim'
require 'sqlite3'
require 'bcrypt'
require_relative './model.rb'

enable :sessions

get('/') do
    slim(:register)
end
  
get('/showlogin') do
    slim(:login)
end

post('/users/new') do
    username = params[:username]
    password = params[:password]
    confirmpassword = params[:confirmpassword]
    year_of_birth = params[:year_of_birth]
    country = params[:country]
    gender = params[:gender]
    #Dock innan här, gör felhantering för att kolla om användaren redan finns, annars ger sinatra error, utan testa ifall den är empty typ och felhantera.
    db = connect_to_db('db/forum2021.db')
    result = check_registration(db, username, password, confirmpassword)
    if result == "goodtogo" #Alltså om en användare med det inskriva namnet inte finns returnerar databasen nil, och då kan vi skapa en ny användare. Funktionen från model.rb returnerar 1,2 eller 3. 1 betyder good to go, skapa användare; 2 betyder att lösenorden ej matchar och 3 betyder att användaren redan finns.
        #Lägg till user:
        password_digest = BCrypt::Password.create(params[:password])
        add_user(username, password_digest, year_of_birth, country, gender)
        redirect('/')
    elsif result == "wrongpass"
        #Felhantering
        content = "Your passwords don't match, please try again."
        returnto = "/"
        linktext = "Try again"
        slim(:standarderror, locals:{content: content, returnto: returnto, linktext: linktext})
    elsif result == "userexist"
        #Felhantering
        content = "This user already exists, try another username."
        returnto = "/"
        linktext = "Try again"
        slim(:standarderror, locals:{content: content, returnto: returnto, linktext: linktext})
    end
end