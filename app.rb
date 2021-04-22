require 'sinatra'
require 'slim'
require 'sqlite3'
require 'bcrypt'
require 'date'
require_relative './model.rb'

enable :sessions

get('/') do #Eventuellt skall denna route döpas om till "/users/new" men eftersom det också är förstasidan så får vi se, jag anser det vara ett befogat undantag från restful.
    if already_logged_in?() == true #Om inloggad användare råkar kryssa ner sidan och sedan bara går in på "localhost:4567" så är den fortfarande inloggad i sessions, men i utan denna åtgärd skulle den dirigerats till registreringssidan och behövt logga ut och logga in igen för att ta sig vidare i applikationen, men nu omdirigeras inloggade användare till /index istället.
        slim(:"forum/index")
    else #Om ingen användare är inloggad så visas registreringsmenyn
        slim(:register)
    end
end
  
get('/showlogin') do
    slim(:login)
end

get('/guestlogin') do #Jag tror att detta skall vara en GET eftersom ingen data direkt skickas med i själva http-requesten.
    session[:username] = nil
    session[:id] = nil
    session[:usertype] = "guest"
    slim(:"forum/index")
end

get('/forum/index') do
    slim(:"forum/index")
end

get('/forum/mysubs') do
    slim(:"forum/mysubs")
end

get('/forum/explore') do
    ordered_subs_array = subs_in_order('db/forum2021.db')
    hot_posts_in_order = posts_in_order('db/forum2021.db') #Här ingår endast posts som har kommentarer - inga comments inte het
    #Lägg till mer saker som där du t.ex. hämtar Dagens posts ordnade efter antal kommentarar. Då kan du använda
    #samma metod "SELECT sub_id, count(sub_id) AS amount FROM subs_users_rel GROUP BY sub_id ORDER BY amount DESC" (för att få fram posten i en array sorterad utifrån på hur många kommenterar de har) <- fast en del modifikationer, se https://www.youtube.com/watch?v=Nl1QNFyaCO8 samt mixtra runt lite med SQL-anrop i DB browser tills du får ut rätt.
    # Dessutom skall du vid detta också endast välja ut posts som är postad idag, vilket du kan göra med en "WHERE publish_date = Time.now" eller hur du nu väljer att strukturera
    # upp tiden, kanske finns en session metod för att få ut exakt tid, annars får du bara köra Time.now varje gång som explore öppnas och se till att du kan konvertera Time.now till dagens datum, eller om det är inom senaste 24h eller så.
    top5_subs_array = []
    i = 0
    while i < 5  #Ev köra denna loopen i slim-filen istället för att göra det här, och bara skicka med ordered_subs_array istället.
        top5_subs_array << ordered_subs_array[i]
        i += 1
    end
    slim(:"forum/explore", locals:{ordered_subs_array: ordered_subs_array, top5_subs_array: top5_subs_array, hot_posts_in_order: hot_posts_in_order}) #Lägg mer till fler saker att skicka med i locals här såsmåningom
end

get('/subs/index') do
    subs_array = subs_in_order('db/forum2021.db')
    slim(:"subs/index", locals:{subs_array: subs_array})
end

get('/posts/new') do
    subs = all_subs('db/forum2021.db')
    slim(:"posts/new", locals:{subs: subs})
end

post('/posts') do
    sub_id = params[:subid]
    title = params[:title]
    content = params[:content]
    user_id = session[:id] #Userid
    publish_date = Time.now.strftime("%Y/%m/%d %H:%M") # Time.now.strftime("%Y/%m/%d %H:%M") #=> "2021/04/19 14:09"
    add_post(content, user_id, title, sub_id, publish_date)
    redirect('/forum/index')
end

get('/posts/:id/edit') do
    post_id = params[:id]
    slim(:"posts/edit", locals:{post_id: post_id})
end

get('/posts/:id') do
    post_id = params[:id]
    comments = all_comments(post_id)
    post_hash = acquire_post_data(post_id)
    slim(:"posts/show", locals:{post_id: post_id, comments: comments, post_hash: post_hash}) #Behöver ev inte skicka med "post_id" eftersom den ändå hämtas som nyckel med värde i post_hash
end

post('/posts/:id/update') do
    post_id = params[:id].to_i
    content = params[:content]
    title = params[:title]
    update_post(content, title, post_id)
    redirect('/forum/explore')
end

post('/posts/:id/delete') do
    post_id = params[:id]
    delete_post(post_id)
    redirect('/forum/explore')
    #Behöver on CASCADE för att ta bort alla kommentarer i databasen när en post tas bort.
end



get('/logout') do 
    session.destroy
    redirect('/')
end



#Implementera cooldown osv på login samt ev ytterligare validering + "strong params" mha black/whitelist.
post('/login') do 
    username = params[:username]
    password = params[:password]
    result = verify_user(username, password)
    if result[0] == true 
        session[:id] = result[1] #användarid:et returneras med från en array i verify_user funktionen i model.rb.
        session[:usertype] = result[2] #Användarens usertype, d.v.s typ av användare, vilket används till authorization på flera ställen i webbapplikationen.
        session[:username] = username
        redirect('/forum/index')
    else
        content = "You have either entered the wrong password or used an invalid username."
        returnto = "/showlogin"
        linktext = "Try again"
        slim(:message, locals:{content: content, returnto: returnto, linktext: linktext})
    end
end



post('/users') do
    username = params[:username]
    password = params[:password]
    confirmpassword = params[:confirmpassword]
    year_of_birth = params[:year_of_birth]
    country = params[:country]
    gender = params[:gender]
    #Dock innan här, gör felhantering för att kolla om användaren redan finns, annars ger sinatra error, utan testa ifall den är empty typ och felhantera.
    db = connect_to_db('db/forum2021.db') #Ev flytta denna till funktionen check_registration i model.rb
    result = check_registration(db, username, password, confirmpassword)
    if result == "goodtogo" #Alltså om en användare med det inskriva namnet inte finns returnerar databasen nil, och då kan vi skapa en ny användare. Funktionen från model.rb returnerar 1,2 eller 3. 1 betyder good to go, skapa användare; 2 betyder att lösenorden ej matchar och 3 betyder att användaren redan finns.
        #Lägg till user:
        password_digest = BCrypt::Password.create(params[:password])
        add_user(username, password_digest, year_of_birth, country, gender)
        redirect('/users/created')
    elsif result == "wrongpass"
        #Felhantering
        content = "Your passwords don't match, please try again."
        returnto = "/"
        linktext = "Try again"
        slim(:message, locals:{content: content, returnto: returnto, linktext: linktext})
    elsif result == "userexist"
        #Felhantering
        content = "This user already exists, try another username."
        returnto = "/"
        linktext = "Try again"
        slim(:message, locals:{content: content, returnto: returnto, linktext: linktext})
    end
end

get('/users/created') do
    content = "User has been created!"
    returnto = "/showlogin"
    linktext = "Login"
    slim(:message, locals:{content: content, returnto: returnto, linktext: linktext})
end

#Tänk på att när man har en CRUD-funktionalitet på en sida och sedan ändrar något i den, så redirectas man tillbaka till routen som visade upp själv gränssnittet 
# stället man var så att säga, och på så vis hämtas data från databasen igen och ändringarna som utförts uppdateras nu även direkt på användarens skärm.





