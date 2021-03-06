require 'sqlite3' #Behövs om jag vill felsöka här utan att arbeta via app.rb och model.rb. (om jag endast testkör mina funktioner t.ex)
module Model
  
  # Connects to database and turns on hash-output from SQL inputs.
  #
  # @param [String] path, path to database
  #
  # @return [SQLite3::Database]
  #
  def connect_to_db(path)
    db = SQLite3::Database.new(path)
    db.results_as_hash = true
    return db
  end

  # Checks that user-registration input data is valid.
  #
  # @param [String] db, the database.
  # @param [String] username, username of new registered user.
  # @param [String] password, entered password of new user.
  # @param [String] confirmpassword, entered password to confirm password of new user.
  # @param [Integer] year_of_birth, entered year of birth for user.
  #
  # @return [String] containing string which tells app.rb which action to take - if the registration is valid or not (several not's)
  #
  def check_registration(db, username, password, confirmpassword, year_of_birth) #Validering av password och t.ex. att year_of_birth är en siffra
    result = db.execute("SELECT * FROM users WHERE username=?", username).first
    if result == nil
      if password == confirmpassword
        if password.length < 8 
          return "passwordshort"
        elsif username.length > 20
          return "usernametoolong"
        elsif year_of_birth.length != 4 || year_of_birth.scan(/\D/).empty? != true #Andra villkoret är true om year_of_birth endast innehåller siffror eller är tom, vilket vi vill (ett riktigt årtal på formen XXXX eftersöks)
          return "invalidyear"
        else #Tydligare kod med att skriva else istället för att bara end:a if-satsen.
          return "goodtogo" #Good to go, bara att skapa användaren.
        end
      else
        return "wrongpass" #Lösenorden matchar inte
      end
    else
      return "userexist" #Användaren finns redan
    end
  end

  # Adds a user to the database.
  #
  # @param [String] username, entered username for new user.
  # @param [String] password_digest, Encrypted password for user.
  # @param [Integer] year_of_birth, user's year of birth
  # @param [String] country, the country of the user
  # @param [String] gender, the gender of the user
  #
  # @return [Boolean] which indicates that user has been added to app.rb
  #
  def add_user(username, password_digest, year_of_birth, country, gender)
      usertype = "user" #När vi skapar en användare blir den en vanlig användare, admin-behörigheter kan erhållas senare.
      db = connect_to_db('db/forum2021.db')
      db.execute('INSERT INTO users (username, pwdigest, country, year_of_birth, gender, usertype) VALUES (?,?,?,?,?,?)',username,password_digest,country,year_of_birth,gender,usertype)
      return true
  end

  # Verifies user who tries to log in.
  #
  # @param [String] username, username of user who is trying to log in
  # @param [String] password, entered password from user who is trying to log in
  #
  # @return [Array] which indicates whether login-attempt is verified or not, and if yes, also includes the user_id and usertype for given user.
  #
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

  # Deletes a user and all his/her posts, comments and subscriptions to subs
  #
  # @param [Integer] user_id, id of user who is being deleted.
  #
  #
  def delete_user(user_id)
    db = connect_to_db('db/forum2021.db')
    db.execute("DELETE FROM users WHERE id = ?", user_id)
    db.execute("DELETE FROM posts WHERE user_id = ?", user_id)
    db.execute("DELETE FROM comments WHERE user_id = ?", user_id)
    db.execute("DELETE FROM subs_users_rel WHERE user_id = ?", user_id)
    #Behöver delete on CASCADE för att ta bort alla posts och kommentarer från denna användare samt subs_users_rel där användaren finns med skall tas bort.
  end

  # Checks if user is already logged in or not
  #
  # @param [String] username, a username which is given by username = session[:username] in app.rb
  #
  # @return [Boolean] whether or not a user is already logged in
  #
  def already_logged_in?(username) #Kollar om det för närvarande är någon användare inloggad.
    if username != nil #Ta bort och skicka med username som input istället från app.rb (i app.rb kan ju session hämtas)
      return true
    else
      return false
    end
  end

  # Returns all subs in a given database
  #
  # @param [String] path, path to database
  #
  # @return [Array] an array with all subs in the database, each being a hash with it's own keys
  #
  def all_subs(path)
    db = connect_to_db(path)
    result = db.execute("SELECT * FROM subs")
    return result 
  end 

  # Makes a list of subs sorted by amount of subscribers 
  #
  # @param [String] path, path to database
  #
  # @return [Array] an array with all subs sorted by amount of subscribers, each being a hash with it's own keys
  #
  def subs_in_order(path) #Returnerar en lista med subs sorterade med avseende på antal prenumeranter
    db = connect_to_db(path)
    all_subs = all_subs(path) #Hämtar in en array med dictionaries för alla subs, skall troligen kommenteras bort eller tas bort då den för närvarande inte fyller någon funktion inom denna funktionen.
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

  # Acquires all the attributes of a given sub
  #
  # @param [Integer] sub_id, id of given sub
  #
  # @return [Hash] which contains all keys with attributes.
  #
  def acquire_sub_data(sub_id) 
    db = connect_to_db('db/forum2021.db')
    subhash = db.execute("SELECT * FROM subs WHERE id = ?", sub_id).first
    return subhash
  end

  # Checks if a user is subscribed to a sub
  #
  # @param [Integer] user_id, the id of the user
  # @param [Integer] sub_id, the id of the sub
  #
  # @return [Array] which tells app.rb if the user is subscribed or not, and if yes, also sends the subcription data
  #
  def is_user_subscribed(user_id, sub_id)
    db = connect_to_db('db/forum2021.db')
    all_relations = db.execute("SELECT * FROM subs_users_rel")
    p "Here's all relations: #{all_relations}"
    potential_relations = all_relations.find_all {|rel1| rel1["sub_id"] == sub_id.to_i} #En array med alla potentiella relationer, d.v.s alla relationer relaterade till given sub_id. Om sub:en inte har några subscribers blir denna en tom array.
    p "Here's potnetila relations: #{potential_relations}"
    sub_user_relation = potential_relations.find {|rel2| rel2["user_id"] == user_id.to_i} #Specifik relation mellan given sub_id och user_id, om usern inte är subscribad blir denna nil.
    p "Here's specific relation: #{sub_user_relation}"
    if sub_user_relation != nil
      return [true, sub_user_relation]
    else
      return false
    end
  end

  # Subscribes user to a sub
  #
  # @param [Integer] user_id, the id of the user
  # @param [Integer] sub_id, the id of the sub
  #
  def subscribe(user_id, sub_id) 
    db = connect_to_db('db/forum2021.db')
    db.execute("INSERT INTO subs_users_rel (user_id, sub_id) VALUES(?,?)", user_id, sub_id)
  end

  # Unsubscribes user to a sub
  #
  # @param [Integer] user_id, the id of the user
  # @param [Integer] sub_id, the id of the sub
  #
  def unsubscribe(user_id, sub_id) 
    db = connect_to_db('db/forum2021.db')
    sub_user_relation = is_user_subscribed(user_id, sub_id)[1] #Får här hashen med relationen till user_id och sub_id, och därav även id:et till själva relationen.
    db.execute("DELETE FROM subs_users_rel WHERE id = ?", sub_user_relation["id"])
  end

  # Gives all posts in order, sorted by amount of comments
  #
  # @param [String] path, the path of the database
  #
  # @return [Array] which includes all the posts as hashed sorted by relevancy (meaning ammount of comments)
  #
  def posts_in_order(path) #Sorted by relevancy
    db = connect_to_db(path)
    post_comment_amount = db.execute("SELECT post_id, count(post_id) AS amount FROM comments GROUP BY post_id ORDER BY amount DESC") #Samma som "relationsarray" i funktionen ovan fast antalet comments för en post istället räknas och presenteras tillsammans med postens post_id.
    p "Hä kommer post_comment_amount:"
    p post_comment_amount
    post_list_ordered_recent = [] #En lista som kommer att byggas upp med alla post_id:s sorterade med avseende på antal kommentarer, men som endast är från idag.
    post_list_ordered_older = [] #En lista som den ovan bara att alla som inte är från idag kommer in här.
    i = 0
    while i < post_comment_amount.length
      post_hash = db.execute('SELECT * FROM posts WHERE id=?', post_comment_amount[i]["post_id"]).first
      if post_hash != nil #Eftersom id:n inte blir i perfekt ordning för post_id om man skapar och tar bort posts så kan vissa i vara tomma och då ge nomethoderror när vi försöker skriva post_hash[...], vilket vi vill förebygga här.
        post_hash["amount"] = post_comment_amount[i]["amount"]
        temp_user = db.execute('SELECT username FROM users WHERE id= ?', post_hash["user_id"]).first
        post_hash["username"] = temp_user["username"] #Skickar in ett attribut i post_hash vid namn "username" med upphovsmannens användarnamn
        # UNDER CONSTRUCTION:
        #En if sats kommer här sedan som kollar ifall posten är från mellan idag och imorgon, och alla posts från mellan idag och imorgon läggs i en lista och är således sorterade efter comments
        # Medans en annan lista, dit alla posts som ej är från mellan idag och imorgon, kommer in ordnade efter antal kommentarer
        #Sedan är det bara att i hot posts printa listan med posts från idag iterativt och sedan den andra listan iterativt.
        post_date = post_hash["publish_date"]
        post_year_month = post_date[0,7] #Får ut första delen av "publish_date"-strängen som innehåller ex "2021/04", d.v.s år och månad.
        post_day = post_date[9,2] #Får ut andra delen av "publish_date"-strängen som innehåller ex "19", d.v.s datum/dag.
        now_date = Time.now.strftime("%Y/%m/%d %H:%M")
        now_year_month = now_date[0,7] #Samma princip som för post_year_month
        now_day = now_date[9,2] #Samma princip som för post_day
        minimum_day = (now_date.to_i - 1) #Igår som integer
        maximum_day = (now_date.to_i + 1) #Imorgon som integer

        if (post_year_month == now_year_month) && (now_day.to_i <= maximum_day) && (now_day.to_i >= minimum_day)
          post_list_ordered_recent << post_hash
        else
          post_list_ordered_older << post_hash
        end
      end
      i += 1
    end
    finished_list = post_list_ordered_recent + post_list_ordered_older
    return finished_list
  end

  # Gives all posts from a given sub, sorted by age
  #
  # @param [Integer] sub_id, the id of the sub
  #
  # @return [Array] which includes all posts hashes from a given sub sorted by age
  #
  def posts_from_sub(sub_id) #Sorted by date, from new to old.
    db = connect_to_db('db/forum2021.db')
    all_posts = db.execute("SELECT * FROM posts WHERE sub_id = ?", sub_id)
    i = 0
    while i < all_posts.length
      post_date = all_posts[i]["publish_date"]
      new_date = post_date[0..3] + post_date[5..6] + post_date[8..9] + post_date[11..12] + post_date[14..15] #Eftersom jag ändrat från formatet som man får via Time.now kan jag inte bara köra .to_i utan får köra en egen mer manuell metod för att göra om post datum till jämförbara integers. Ex: "2021/04/04 21:59" => "202104042159"
      all_posts[i]["publish_date"] = new_date.to_i
      i += 1
    end
    sorted_posts = all_posts.sort_by{|hash| hash["publish_date"]}.reverse #Sorterar alla hashes inuti all_posts array med avseende på nyckeln "publish_date" och reversar så att störst publish_date (d.v.s nyast) hamnar i början av arrayen.
    return sorted_posts
  end
  # Adds a post to the database
  #
  # @param [String] content, the content of the post
  # @param [Integer] user_id, the id of the user
  # @param [String] title, the title of the post
  # @param [Integer] sub_id, the id of the sub
  # @param [String] publish_date, the publish date of the post
  # 
  #
  def add_post(content, user_id, title, sub_id, publish_date)
    db = connect_to_db('db/forum2021.db')
    db.execute("INSERT INTO posts (content, user_id, title, sub_id, publish_date) VALUES (?,?,?,?,?)", content, user_id, title, sub_id, publish_date)
  end

  # Updates an existing post in database
  #
  # @param [String] content, new content of post
  # @param [String] title, new title of the post
  # @param [Integer] post_id, the id of the post
  #
  def update_post(content, title, post_id)
    db = connect_to_db('db/forum2021.db')
    if title != "" #Om titlen ej skall ändras skriver användaren inte in någon input i title-inputen i formuläret och då ändras inte post:ens titel. (om användaren inte skriver något input returneras en tom sträng)
      db.execute("UPDATE posts SET content = ?, title = ? WHERE id = ?", content, title, post_id)
    else
      db.execute("UPDATE posts SET content = ? WHERE id = ?", content, post_id)
    end
  end

  # Deletes a post
  #
  # @param [Integer] post_id, the id of the post
  #
  def delete_post(post_id)
    db = connect_to_db('db/forum2021.db')
    db.execute("DELETE FROM posts WHERE id = ?", post_id)
    db.execute("DELETE FROM comments WHERE post_id = ?", post_id)
    #Behöver ON CASCADE för att ta bort alla comments i databasen när en post tas bort (comment på posten).
  end
  # Checks so that a post being created i valid/verified
  #
  # @param [String] content, the content of the post
  # @param [Integer] user_id, the id of the user who creates the post
  # @param [String] title, the title of the new post
  # @param [Integer] sub_id, the id of the sub where the post will be posted
  #
  # @return [String] where the string either tells app.rb that post's good to go or what problem the posts has
  #
  def check_post(content, user_id, title, sub_id)
    subs = all_subs('db/forum2021.db')
    sub_id_list = []
    i = 0
    while i < subs.length
      sub_id_list << subs[i]["id"]
      i += 1
    end
    
    if user_id == nil #Kontrollerar så att en guest-user inte av misstag kan skapa en post.
      return "invaliduser"
    elsif title.length > 40 || title.length == 0
      return "invalidtitle"
    elsif content.length == 0
      return "nocontent"
    elsif sub_id_list.include?(sub_id.to_i) != true #Om sub_id:en inte finns har något tokigt hänt.
      return "invalidsub"
    else
      return "goodtogo"
    end
  end

  # Checks the update of a post
  #
  # @param [String] content, the updated content of the post
  # @param [String] title, the updated title of the post
  #
  # @return [String] where the string either tells app.rb that the update is good to go or what problems it has
  #
  def check_update(content, title) 
    if title.length > 40 || title.length == 0
      return "invalidtitle"
    elsif content.length == 0
      return "nocontent"
    else
      return "goodtogo"
    end
  end

  # Gives all comments on a post
  #
  # @param [Integer] post_id, the id of the post
  #
  # @return [Array] which contains all comment hashes for comments on given post
  #
  def all_comments(post_id)
    db = connect_to_db('db/forum2021.db')
    comments = db.execute("SELECT * FROM comments WHERE post_id = ?", post_id)
    if comments != nil
      i = 0
      while i < comments.length
        temp_user = db.execute('SELECT username FROM users WHERE id= ?', comments[i]["user_id"]).first
        comments[i]["username"] = temp_user["username"]
        i += 1
      end
    end
    return comments
  end

  # Adds a comment to database
  #
  # @param [Integer] post_id, the id of the post which the comment is on
  # @param [String] content, the content of the comment
  # @param [Integer] user_id, the id of the user who writes the comment
  # @param [String] publish_date, the publish date of the comment
  #
  def add_comment(post_id, content, user_id, publish_date)
    db = connect_to_db('db/forum2021.db')
    db.execute("INSERT INTO comments (post_id, content, user_id, publish_date) VALUES (?,?,?,?)", post_id, content, user_id, publish_date)
  end

  # Checks a comment so it's valid
  #
  # @param [String] content, the content of the comment
  # @param [Integer] user_id, the id of the user who writes the comment
  # 
  # @return [String] whichs tells app.rb whether the comment is valid or not, and if not, what problem it has
  #
  def check_comment(content, user_id) #Behöver ej kontrollera post_id då comment-fältet ej visas utan att man är inne på sidan för en specifik post.
    if user_id == nil #Kontrollerar så att en guest-user inte av misstag kan skapa en post.
      return "invaliduser"
    elsif content.length == 0
      return "nocontent"
    else
      return "goodtogo"
    end
  end

  # Deletes a comment
  #
  # @param [Integer] comment_id, the id of the comment
  #
  def delete_comment(comment_id)
    db = connect_to_db('db/forum2021.db')
    db.execute("DELETE FROM comments WHERE id = ?", comment_id)
  end

  # Acquires data from a given post
  #
  # @param [Integer] post_id, the id of the post
  #
  # @return [Hash] which includes keys to all attributes of given post
  #
  def acquire_post_data(post_id)
    db = connect_to_db('db/forum2021.db')
    post = db.execute("SELECT * FROM posts WHERE id = ?", post_id).first
    temp_user = db.execute('SELECT username FROM users WHERE id= ?', post["user_id"]).first
    post["username"] = temp_user["username"] #Skickar med username i hashen till varje post
    return post
  end

end