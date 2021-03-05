def connect_to_db(path)
    db = SQLite3::Database.new(path)
    db.results_as_hash = true
    return db
end

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
      if (BCrypt::Password.new(pw_digest) == password) && (username == result["username"])
        return [true, id] #Detta betyder att användaren blivit authenticatad
      else
        return [false]
        #Fel lösenord
      end
    else 
      return [false]
      #Användaren finns ej, av säkerhetsskäl skrivs samma felmeddelande ut som vid endast fel lösenord. (Så att hackare inte vet att de träffat rätt användare eller dylikt)
    end
end