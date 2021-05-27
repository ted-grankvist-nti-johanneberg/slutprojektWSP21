require 'sinatra'
require 'slim'
require 'sqlite3'
require 'bcrypt'
require 'date'
require_relative './model.rb'

enable :sessions

include Model

# Before almost every route check if session[:usertype] == nil (Those excluded are necessary for non-logged in users to either register or log in)
#
before do
    if  session[:usertype] == nil && request.path_info != '/' &&  request.path_info != '/showlogin' &&  request.path_info != '/guestlogin' && request.path_info != '/login' && request.path_info != '/users' && request.path_info != '/users/created' #Login routen är med p.g.a annars hinner en som loggar in inte bli assignad en session[:usertype] = "user" eller "admin". users-routar är med för annars går det inte att skapa en ny användare om man inte är inloggad, vilket skulle vara väldigt konstigt.
       redirect('/showlogin') #Användaren skickas till loginsidan.
    end
end
# Before showing login page, check if user is already logged in
#
before('/showlogin') do #Om redan inloggad användare skriver in att de vill komma in på login-sidan skickas de endast tillbaka till dit de var.
    if session[:usertype] == "admin" || session[:usertype] == "user"
        redirect back
    end
end

# Before showing create post page, confirm that user is logged in (as a normal user, guest-user can't post)
#
before('/posts/new') do #Om guest-users eller icke-inloggade skriver in att de vill komma till create post skickas dem tillbaka till dit de var.
    if session[:usertype] != "admin" && session[:usertype] != "user"
        redirect back
    end
end

# Display Landing Page which also is the registration page.
#
get('/') do #Eventuellt skall denna route döpas om till "/users/new" men eftersom det också är förstasidan så får vi se, jag anser det vara ett befogat undantag från restful.
    username = session[:username]
    if already_logged_in?(username) == true #Om inloggad användare råkar kryssa ner sidan och sedan bara går in på "localhost:4567" så är den fortfarande inloggad i sessions, men i utan denna åtgärd skulle den dirigerats till registreringssidan och behövt logga ut och logga in igen för att ta sig vidare i applikationen, men nu omdirigeras inloggade användare till /index istället.
        slim(:"forum/index")
    else #Om ingen användare är inloggad så visas registreringsmenyn
        slim(:register)
    end
end

# Displays login page
#
get('/showlogin') do
    slim(:login)
end

# Enters user into a "guest-user" account, and is redirected to the forum explore page.
#
get('/guestlogin') do #Jag tror att detta skall vara en GET eftersom ingen data direkt skickas med i själva http-requesten.
    session[:username] = nil
    session[:id] = nil
    session[:usertype] = "guest" 
    slim(:"forum/index")
end

# Enters user into forum index page.
#
get('/forum/index') do
    slim(:"forum/index")
end

# Enters users into the explore page on forum
#
# see Model@subs_in_order
# see Model@posts_in_order
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
# Enters user into the list of all subs.
#
# see Model@subs_in_order
get('/subs/index') do
    subs_array = subs_in_order('db/forum2021.db')
    slim(:"subs/index", locals:{subs_array: subs_array})
end

# Enters user into viewing a specific sub.
#
# @param [Integer] :id, the id of the sub.
#
# see Model@subs_in_order
# see Model@posts_from_sub
get('/subs/:id') do
    sub_id = params[:id]
    all_subs = subs_in_order('db/forum2021.db')
    sub_hash = all_subs.find {|sub1| sub1["id"] == sub_id.to_i} #Returnerar den subbens hash vars id har id:et sub_id, och som inkluderar nyckeln "amount".
    sorted_posts = posts_from_sub(sub_id)
    slim(:"subs/show", locals:{sub_id: sub_id, sorted_posts: sorted_posts, sub_hash: sub_hash}) #Behöver ev inte skicka med "sub_id" eftersom den ändå hämtas som nyckel med värde i sorted_posts
end
# Subscribes user to a sub.
#
# @param [Integer] :id, the id of the sub.
#
# see Model@subscribe
post('/subs/:id/subscribe') do 
    sub_id = params[:id]
    user_id = session[:id]
    subscribe(user_id, sub_id) 
    redirect back
end

# Unsubscribes user from a sub.
#
# @param [Integer] :id, the id of the sub.
#
# see Model@unsubscribe
post('/subs/:id/unsubscribe') do
    sub_id = params[:id]
    user_id = session[:id]
    unsubscribe(user_id, sub_id) 
    redirect back
end
# Enters user into create-post page.
#
# see Model@all_subs
get('/posts/new') do
    subs = all_subs('db/forum2021.db')
    slim(:"posts/new", locals:{subs: subs})
end
# Recieves post content from create-post attempt from user and verifies/validates it, and then redirects back user to either error message or to forum index page.
#
# @param [Integer] subid, the id of the sub where post will be posted.
# @param [String] title, the title of the new post
# @param [String] content, the content of the new post
#
# see Model@check_post
# see Model@add_post
post('/posts') do
    sub_id = params[:subid]
    title = params[:title]
    content = params[:content]
    user_id = session[:id] #Userid
    publish_date = Time.now.strftime("%Y/%m/%d %H:%M") # Time.now.strftime("%Y/%m/%d %H:%M") #=> "2021/04/19 14:09"
    result = check_post(content, user_id, title, sub_id)
    if result == "goodtogo" 
        add_post(content, user_id, title, sub_id, publish_date)
        redirect('/forum/index')
    elsif result == "invaliduser"
        #Felhantering
        content = "Try logging in before creating a post."
        returnto = "/showlogin"
        linktext = "Login"
        slim(:message, locals:{content: content, returnto: returnto, linktext: linktext})
    elsif result == "invalidtitle"
        #Felhantering
        content = "Your title is either nonexistent or too long - it must be no longer than 40 characters."
        returnto = "/posts/new"
        linktext = "Try again"
        slim(:message, locals:{content: content, returnto: returnto, linktext: linktext})
    elsif result == "nocontent"
        #Felhantering
        content = "Your post doesn't include any content, which is sort of it's purpose."
        returnto = "/posts/new"
        linktext = "Try again"
        slim(:message, locals:{content: content, returnto: returnto, linktext: linktext})
    elsif result == "invalidsub"
        #Felhantering, specifikt denna borde ej vara möjlig men den är implementerad för säkerhetens skull.
        content = "You have somehow entered an invalid sub, try one of the existing listed ones."
        returnto = "/posts/new"
        linktext = "Try again"
        slim(:message, locals:{content: content, returnto: returnto, linktext: linktext})
    end
end
# Shows user the edit page for a post.
#
# @param [Integer] :id, the id of the post.
#
# see Model@acquire_post_data
get('/posts/:id/edit') do
    post_id = params[:id] #Behövs för att hämta data för rätt post.
    post_hash = acquire_post_data(post_id) #Används för att kunna skriva ut redigerbar title och content i edit-formuläret.
    slim(:"posts/edit", locals:{post_id: post_id, post_hash: post_hash}) #Räcker egentligen med att skicka med post_hash eftersom den också innehåller post_id, men blir tydligare att skicka med post_hash till vyn.
end
# Shows user the page for a post (where comments can be see etc).
#
# @param [Integer] :id, the id of the post.
#
# see Model@all_comments
# see Model@acquire_post_data
get('/posts/:id') do
    post_id = params[:id]
    comments = all_comments(post_id)
    post_hash = acquire_post_data(post_id)
    slim(:"posts/show", locals:{post_id: post_id, comments: comments, post_hash: post_hash}) #Behöver ev inte skicka med "post_id" eftersom den ändå hämtas som nyckel med värde i post_hash
end
# Updates the content of a post.
#
# @param [Integer] :id, the id of the post.
# @param [String] content, the updated content of the post.
# @param [String] title, the updated title of the  post.
#
# see Model@check_update
# see Model@update_post
post('/posts/:id/update') do #Skall läggas till beforeblock som kontrolllerar att användaren är inloggad med rätt inlogg (ägaren elr admin)
    post_id = params[:id].to_i
    content = params[:content]
    title = params[:title]
    result = check_update(content, title)
    if result == "goodtogo"
        update_post(content, title, post_id)
        redirect('/forum/explore')
    elsif result == "invalidtitle"
        content = "Your title is either nonexistent or too long - it must be no longer than 40 characters."
        returnto = "/posts/#{post_id}/edit"
        linktext = "Try again"
        slim(:message, locals:{content: content, returnto: returnto, linktext: linktext})
    elsif result == "nocontent"
        content = "Your post doesn't include any content now, which is sort of it's purpose."
        returnto = "/posts/#{post_id}/edit"
        linktext = "Try again"
        slim(:message, locals:{content: content, returnto: returnto, linktext: linktext})
    end
end
# Deletes a post and redirects user back to explore page of forum.
#
# @param [Integer] :id, the id of the post.
#
# see Model@delete_post
post('/posts/:id/delete') do
    post_id = params[:id]
    delete_post(post_id)
    redirect('/forum/explore')
end
# Adds a comment to a post.
#
# @param [Integer] post_id, the id of the post the comment is on.
# @param [String] content, the content of the comment.
#
# see Model@check_comment
# see Model@add_comment
post('/comments') do
    content = params[:content]
    user_id = session[:id] #Userid
    post_id = params[:post_id]
    publish_date = Time.now.strftime("%Y/%m/%d %H:%M")
    result = check_comment(content, user_id)
    if result == "goodtogo"
        add_comment(post_id, content, user_id, publish_date)
        session[:current_post_id] = post_id #Behöver skicka data via sessions då det inte går via redirect.
        redirect back #Kommando som redirectar tillbaka användaren dit den innan var.
    elsif result == "invaliduser"
        content = "Try logging in before commenting."
        returnto = "/showlogin"
        linktext = "Login"
        slim(:message, locals:{content: content, returnto: returnto, linktext: linktext})
    elsif result == "nocontent"
        content = "Your comment doesn't include any content, which is sort of it's purpose."
        returnto = "/posts/#{post_id.to_i}"
        linktext = "Try again"
        slim(:message, locals:{content: content, returnto: returnto, linktext: linktext})
    end
end

# Deletes a comment.
#
# @param [Integer] :id, the id of the comment.
#
# see Model@delete_comment
post('/comments/:id/delete') do
    comment_id = params[:id]
    delete_comment(comment_id)
    redirect back
end

# Logs out a user and destroys the session. Redirects to register page.
#
get('/logout') do 
    session.destroy
    redirect('/')
end


# Logs in a user and redirects them to index page of forum. (with validation etc)
#
# @param [String] username, the username of the user who logs in.
# @param [String] password, the entered password of the user, which hopefully is correct.
#
# see Model@verify_user
post('/login') do 
    username = params[:username]
    password = params[:password]
    if session[:lastlogin] == nil || Time.now - session[:lastlogin] > 15 #15 sekunders cooldown mellan varje inloggningsförsök. Om inget inloggningsförsök har skett än skall användaren också kunna logga in, därav första villkoret.
        result = verify_user(username, password)
        if result[0] == true 
            session[:id] = result[1] #användarid:et returneras med från en array i verify_user funktionen i model.rb.
            session[:usertype] = result[2] #Användarens usertype, d.v.s typ av användare, vilket används till authorization på flera ställen i webbapplikationen.
            session[:username] = username
            redirect('/forum/index')
        else
            session[:lastlogin] = Time.now #Skyddar servern från att nästkommanden inloggningsförsök spammas (att man försöker brute-force hacka) m.h.a första if-satsen i routen.
            content = "You have either entered the wrong password or used an invalid username."
            returnto = "/showlogin"
            linktext = "Try again"
            slim(:message, locals:{content: content, returnto: returnto, linktext: linktext})
        end
    else
        session[:lastlogin] = Time.now #Skyddar servern från att nästkommanden inloggningsförsök spammas (att man försöker brute-force hacka) m.h.a första if-satsen i routen.
        content = "Please wait at least 15 seconds inbetween every log-in attempt (For the security of your account)."
        returnto = "/showlogin"
        linktext = "Try again"
        slim(:message, locals:{content: content, returnto: returnto, linktext: linktext})
    end
end


# Creates a user and adds it into the database, then redirects to login page.
#
# @param [String] username, the username of the user who logs in.
# @param [String] password, the entered password from the user.
# @param [String] confirmpassword, the confirmed password from the user.
# @param [String] year_of_birth, the enter year of birth of user.
# @param [String] country, the entered country of the user.
# @param [String] gender, the entered gender of the user.
#
# see Model@check_registration
# see Model@connect_to_db
# see Model@add_user
post('/users') do
    username = params[:username]
    password = params[:password]
    confirmpassword = params[:confirmpassword]
    year_of_birth = params[:year_of_birth]
    country = params[:country]
    gender = params[:gender]
    #Dock innan här, gör felhantering för att kolla om användaren redan finns, annars ger sinatra error, utan testa ifall den är empty typ och felhantera.
    db = connect_to_db('db/forum2021.db') #Ev flytta denna till funktionen check_registration i model.rb
    result = check_registration(db, username, password, confirmpassword, year_of_birth)
    if result == "goodtogo" #Alltså om en användare med det inskriva namnet inte finns returnerar databasen nil, och då kan vi skapa en ny användare. Funktionen från model.rb returnerar 1,2 eller 3. 1 betyder good to go, skapa användare; 2 betyder att lösenorden ej matchar och 3 betyder att användaren redan finns.
        #Lägg till user:
        password_digest = BCrypt::Password.create(params[:password])
        add_user(username, password_digest, year_of_birth, country, gender)
        redirect('/users/created')
    elsif result == "usernametoolong"
        #Felhantering
        content = "That username is too long, try a username with no more than 20 characters"
        returnto = "/"
        linktext = "Try again"
        slim(:message, locals:{content: content, returnto: returnto, linktext: linktext})
    elsif result == "invalidyear"
        #Felhantering
        content = "Invalid year of birth"
        returnto = "/"
        linktext = "Try again"
        slim(:message, locals:{content: content, returnto: returnto, linktext: linktext})
    elsif result == "wrongpass"
        #Felhantering
        content = "Your passwords don't match, please try again."
        returnto = "/"
        linktext = "Try again"
        slim(:message, locals:{content: content, returnto: returnto, linktext: linktext})
    elsif result == "passwordshort"
        #Felhantering
        content = "That password is too short, please enter a password with at least 8 characters."
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

# Shows user has been created message.
#
get('/users/created') do
    content = "User has been created!"
    returnto = "/showlogin"
    linktext = "Login"
    slim(:message, locals:{content: content, returnto: returnto, linktext: linktext})
end

# Deletes a logged in user and redirects to registration (kills session)
#
# @param [Integer] :id, the id of the user.
#
# see Model@delete_user
post('/users/:id/delete') do
    user_id = params[:id]
    session.destroy
    delete_user(user_id)
    redirect('/')
end






