require 'sqlite3' #Behövs om jag vill felsöka här utan att arbeta via app.rb och model.rb. (om jag endast testkör mina funktioner t.ex)

def connect_to_db(path)
    db = SQLite3::Database.new(path)
    db.results_as_hash = true
    return db
end

=begin
def connect_to_db2(path) #För att få ut data från databasen i en array istället för hash.
  db = SQLite3::Database.new(path)
  return db
end
=end #P.g.a används ännu ej

def check_registration(db, username, password, confirmpassword)
    result = db.execute("SELECT * FROM users WHERE username=?", username).first
    if result == nil
        if password == confirmpassword
            return "goodtogo" #Good to go, bara att skapa användaren.
        else
            return "wrongpass" #Lösenorden matchar inte
        end
    else
        return "userexist" #Användaren finns redan
    end
end

def add_user(username, password_digest, year_of_birth, country, gender)
    usertype = "user" #När vi skapar en användare blir den en vanlig användare, admin-behörigheter kan erhållas senare.
    db = connect_to_db('db/forum2021.db')
    db.execute('INSERT INTO users (username, pwdigest, country, year_of_birth, gender, usertype) VALUES (?,?,?,?,?,?)',username,password_digest,country,year_of_birth,gender,usertype)
    return true
end

def verify_user(username, password)
    db = connect_to_db('db/forum2021.db')
    result = db.execute("SELECT * FROM users WHERE username=?", username).first
    if result != nil
      pw_digest = result["pwdigest"]
      id = result["id"]
      usertype = result["usertype"]
      if (BCrypt::Password.new(pw_digest) == password) && (username == result["username"])
        return [true, id, usertype] #Detta betyder att användaren blivit authenticatad. Normalt brukar jag hämta ytterligare data om användaren via nya SQL-anrop men jag ansåg det rimligt att hålla användarnamn, id, och usertype med i sessions då dessa kan komma att behövas frekvent under användarens besök på hemsidan.
      else
        return [false]
        #Fel lösenord
      end
    else 
      return [false]
      #Användaren finns ej, av säkerhetsskäl skrivs samma felmeddelande ut som vid endast fel lösenord. (Så att hackare inte vet att de träffat rätt användare eller dylikt)
    end
end

def collect_info_user(username, instructions)
  #Här skall du skicka med data som sedan förklarar för funktionen
  #Vad den skall efterfråga med sitt SQL anrop (eventuellt behöver du göra flera av dessa funktioner och kan inte ha en "standardfunktion" som täcker allt)
end

def already_logged_in?() #Kollar om det för närvarande är någon användare inloggad.
  if session[:username] != nil
    return true
  else
    return false
  end
end

def all_subs(path)
  db = connect_to_db(path)
  result = db.execute("SELECT * FROM subs")
  return result 
end


def subs_in_order(path) #Returnerar en lista med subs sorterade med avseende på antal prenumeranter
  db = connect_to_db(path)
  all_subs = all_subs(path) #Hämtar in en array med dictionaries för alla subs, skall troligen kommenteras bort eller tas bort då den för närvarande inte fyller någon funktion
  relationsarray = db.execute("SELECT sub_id, count(sub_id) AS amount FROM subs_users_rel GROUP BY sub_id ORDER BY amount DESC") #Får ut en array innehållande dictionaries innehållande sub_id och antalet prenumerationer som respektive sub för sub_id har, och sedan är arrayen ordnad således att dictionaryn till sub:en med flest prenumerationer kommer på position [0], näst flest på [1] osv. (fallande). Thus returneras lika många rows som det finns subs från detta anropet, en för varje sub.
  #p "här kommer relationsarray: #{relationsarray}"
  i = 0
  sub_list_ordered = [] #En lista som kommer att byggas upp med alla subs sorterade med avseende på antal prenumeranter.
  while i < relationsarray.length
    sub_hash = db.execute('SELECT * FROM subs WHERE id=?', relationsarray[i]["sub_id"]).first #SQL-anropet tar ut en sub och all dess attribut givet ordningen från relationsarray anropet. relationsarray[i]["sub_id"] returnerar primärnyckeln för subben vars dictionary ligger på position i.
    #p "här kommer sub_hash: #{sub_hash}"
    sub_hash["amount"] = relationsarray[i]["amount"] #Lägger till en nyckel med värdet amount från tillhörande sub-dict i relationsarray (därav relationsarray[i]....).
    #p "här kommer sub_hash uppdaterad med amountvärde: #{sub_hash}"
    sub_list_ordered << sub_hash
    i += 1
  end
  return sub_list_ordered
end

def posts_in_order(path)
  db = connect_to_db(path)
  post_comment_amount = db.execute("SELECT post_id, count(post_id) AS amount FROM comments GROUP BY post_id ORDER BY amount DESC") #Samma som "relationsarray" i funktionen ovan fast antalet comments för en post istället räknas och presenteras tillsammans med postens post_id.
  post_list_ordered_today = [] #En lista som kommer att byggas upp med alla post_id:s sorterade med avseende på antal kommentarer, men som endast är från idag.
  post_list_ordered_older = [] #En lista som den ovan bara att alla som inte är från idag kommer in här.
  i = 0
  while i < post_comment_amount.length
    post_hash = db.execute('SELECT * FROM posts WHERE id=?', post_comment_amount[i]["post_id"]).first
    post_hash["amount"] = post_comment_amount[i]["amount"]
    #En if sats kommer här sedan som kollar ifall posten är från idag eller inte, och alla posts från idag läggs i en lista och är således sorterade efter comments
    # Medans en annan lista, dit alla posts som ej är från idag, kommer in ordnade efter antal kommentarer
    #Sedan är det bara att i hot posts printa listan med posts från idag iterativt och sedan den andra listan iterativt.

    i += 1
  end


=begin
def find_subs_where(path, condition)
  db = connect_to_db2(path)
  result = db.execute("SELECT * FROM subs WHERE username=? ", username).first
  ...
end
=end



