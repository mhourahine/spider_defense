require 'gosu'

module GameSettings
	RESOURCE_DIR = './resources'
	FONT = './resources/paraaminobenzoic.ttf'
	STARTING_LIVES = 1
	WEB_TIME = 3000
end

module ZOrder
	BACKGROUND = 0
	WEB=1
	PLAYER=2
	ANT=2
	FLY=2
	TITLE=3
end

# return true if two objects overlap
def overlap?(object1, object2)
	#upper left corner
	lx1 = object1.x
	ly1 = object1.y

	lx2 = object2.x
	ly2 = object2.y
	
	#lower right corner
	rx1 = object1.x + object1.class::WIDTH
	ry1 = object1.y + object1.class::HEIGHT

	rx2 = object2.x + object2.class::WIDTH
	ry2 = object2.y + object2.class::HEIGHT

	if rx1 - lx2 < 5 or
			rx2 - lx1 < 5 then
		return false
	end

	if ry1 - ly2 < 5 or
			ry2 - ly1 < 5 then
		return false
	end

	return true
end

class SpiderPlayer
	HEIGHT = WIDTH = 32

	attr_accessor :x, :y, :lives
	
	def initialize
		@images = Gosu::Image.load_tiles("#{GameSettings::RESOURCE_DIR}/Spider.png", WIDTH, WIDTH)
		@x = @y = 0
		@vel = 3
		@lives = GameSettings::STARTING_LIVES 
	end

	def moveTo(x, y)
		@x, @y = x, y
	end

	def moveUp
		self.moveTo(@x, @y-@vel)
	end

	def moveDown
		self.moveTo(@x, @y+@vel)
	end

	def moveLeft
		self.moveTo(@x-@vel, @y)
	end

	def moveRight
		self.moveTo(@x+@vel, @y)
	end

	def hit
		@lives -= 1
	end

	def is_dead?
		return @lives <= 0
	end

	def draw
		frame = Gosu.milliseconds / 300 % 2
		@images[frame].draw(@x, @y, ZOrder::PLAYER)
	end
end

class Fly
	HEIGHT = WIDTH = 16

	attr_accessor :x, :y, :direction, :speed, :caught

	def initialize(x, y, direction, speed)
		@images = Gosu::Image.load_tiles("#{GameSettings::RESOURCE_DIR}/Fly.png", WIDTH, WIDTH)
		@x = x
		@y = y
		@direction = direction
		@speed = speed
	end

	def x_delta
		Math.sin(direction * Math::PI / 180)
	end

	def y_delta
		-Math.cos(direction * Math::PI / 180)
	end

	def move
		unless caught
			@x += @speed * x_delta 
			@y += @speed * y_delta
		end
	end

	def draw
		frame = Gosu.milliseconds / 100 % 2

		# flip image horizontally when moving to the right
		if (x_delta > 0)
			@images[frame].draw(@x + WIDTH, @y, ZOrder::FLY, -1.0, 1.0)
		else
			@images[frame].draw(@x, @y, ZOrder::FLY)
		end
	end
end

class Web
	HEIGHT = WIDTH = 23

	attr_accessor :x, :y

	def initialize(x, y)
		@image = Gosu::Image.new("#{GameSettings::RESOURCE_DIR}/Web.png")
		@x = x
		@y = y
		@time_spun = Gosu.milliseconds
		@flies_caught = []
	end

	def age
		return Gosu.milliseconds - @time_spun
	end

	def empty?
		return @flies_caught.empty?
	end

	def add_fly(fly)
		@flies_caught.push(fly)
	end

	def draw
		@image.draw(@x, @y, ZOrder::WEB)
	end
end


class BugGame < Gosu::Window
	WEB_SPIN_MAXRATE = 300
	WIDTH = 640
	HEIGHT = 480

  def initialize
    super WIDTH, HEIGHT
    self.caption = "Spider Defense"
		self.fullscreen = true

		@background_image = Gosu::Image.new("#{GameSettings::RESOURCE_DIR}/Background.png", :tileable => true)

		@spider = SpiderPlayer.new
		@spider.moveTo(320, 240)

		@running = false
		reset
  end
	
	def reset
		# store time when last web was spun to rate limit
		@last_web_spin = 0

		@spider = SpiderPlayer.new
		@spider.moveTo(320, 240)
		@webs = []
		@flies = []

		@gameover = false
	end

	def start
		reset
		spawn_flies
		@running = true
		@paused = false
	end

	def restart
		reset
		start
	end

	def pause
		@paused = true
	end

	def unpause 
		@paused = false 
	end

	def spin_web
		@webs.push(Web.new(@spider.x + SpiderPlayer::WIDTH/2 - Web::WIDTH/2,
											 @spider.y + SpiderPlayer::WIDTH/2 - Web::WIDTH/2))
		@last_web_spin = Gosu.milliseconds
	end
	
	def spawn_flies
		# avoid the middle area to make sure flies aren't spawned on top
		# of player
		spawn_points_x = [*20..(WIDTH/2-100)] + [*(WIDTH/2+100)..WIDTH]
		spawn_points_y = [*20..(HEIGHT/2-100)] + [*(HEIGHT/2+100)..HEIGHT]
		20.times { @flies.push(Fly.new(spawn_points_x.sample, spawn_points_y.sample, rand(0..360), 1)) } 
	end

	# if any flies are near webs, catch them in the web
	def catch_flies
		@flies.each do |f|
			@webs.each do |w|
				if overlap?(w, f)
					f.caught = true
					w.add_fly(f)
				end
			end
		end
	end

	def all_caught?
		return @flies.reject{ |f| f.caught }.empty?
	end

	def move_flies
		@flies.each do |f|
			f.move

			#if fly is at edge then choose new random angle
			if f.x < 5 
				f.direction = rand(5..175)
			elsif f.x > BugGame::WIDTH - Fly::WIDTH 
				f.direction = rand(185..355)
			end

			if f.y < 5 
				f.direction = rand(95..265)
			elsif f.y > BugGame::HEIGHT - Fly::WIDTH
				f.direction = rand(-85..85) 
			end
		end
	end

	def remove_webs
		@webs = @webs.reject{|w| w.age > GameSettings::WEB_TIME and w.empty?}
	end

	def check_player_collisions
		@flies.each do |f|
			if overlap?(@spider, f)
				@spider.hit

				if @spider.is_dead?
					@gameover = true
					break
				end
			end
		end
	end

	def game_controls
		if Gosu.button_down? Gosu::KB_LEFT or Gosu::button_down? Gosu::GP_LEFT
			@spider.moveLeft unless @spider.x <= 0 
		end
		if Gosu.button_down? Gosu::KB_RIGHT or Gosu::button_down? Gosu::GP_RIGHT
			@spider.moveRight unless @spider.x > BugGame::WIDTH - SpiderPlayer::WIDTH - 5
		end
		if Gosu.button_down? Gosu::KB_UP or Gosu::button_down? Gosu::GP_UP
			@spider.moveUp unless @spider.y <= 5
		end
		if Gosu.button_down? Gosu::KB_DOWN or Gosu::button_down? Gosu::GP_DOWN
			@spider.moveDown unless @spider.y > BugGame::HEIGHT - SpiderPlayer::WIDTH - 5
		end
		if Gosu.button_down? Gosu::KB_SPACE or Gosu::button_down? Gosu::GP_BUTTON_0
			spin_web if Gosu.milliseconds - @last_web_spin > WEB_SPIN_MAXRATE 
		end
		if Gosu.button_down? Gosu::KB_ESCAPE
			pause
		end
	end

	def show_title_screen
		text_options = { width: WIDTH, align: :center, font: GameSettings::FONT }
		title_image = Gosu::Image.from_text("Spider Defense", 100, text_options)
		title_image.draw(0, HEIGHT/5, ZOrder::TITLE)

		prompt_image = Gosu::Image.from_text("Press Enter to Start", 40, text_options)
		prompt_image.draw(0, 2*HEIGHT/3, ZOrder::TITLE)
	end

	def show_pause_screen
		text_options = { width: WIDTH, align: :center, font: GameSettings::FONT }
		pause_image = Gosu::Image.from_text("Paused", 100, text_options)
		pause_image.draw(0, HEIGHT/2-100, ZOrder::TITLE)

		continue_image = Gosu::Image.from_text("Press Enter to Continue", 25, text_options)
		continue_image.draw(0, HEIGHT/2, ZOrder::TITLE)

		restart_image = Gosu::Image.from_text("Press R to Restart", 25, text_options)
		restart_image.draw(0, HEIGHT/2+100, ZOrder::TITLE)
	end
  
	def show_game_over
		text_options = { width: WIDTH, align: :center, font: GameSettings::FONT }
		game_over_image = Gosu::Image.from_text("Game Over", 100, text_options)
		game_over_image.draw(0, HEIGHT/2-100, ZOrder::TITLE)
		
		if all_caught?
			game_over_image = Gosu::Image.from_text("You win!", 80, text_options)
			game_over_image.draw(0, HEIGHT/2, ZOrder::TITLE)
		end

		restart_image = Gosu::Image.from_text("Press Enter to Start New Game", 25, text_options)
		restart_image.draw(0, HEIGHT/2+100, ZOrder::TITLE)
	end

  def update
		if @running and not @paused and not @gameover
			game_controls
			check_player_collisions
			move_flies
			catch_flies
			remove_webs

			@gameover = true if all_caught?
		elsif @paused
			unpause if Gosu.button_down? Gosu::KB_RETURN
			restart if Gosu.button_down? Gosu::KB_R
		else
			start if Gosu.button_down? Gosu::KB_RETURN
		end
  end
  
  def draw
		if not @running and not @paused
			show_title_screen
		end
		
		if @paused
			show_pause_screen
		end

		if @gameover
			show_game_over
		end
		
		@webs.each { |w| w.draw }
		@flies.each { |f| f.draw }
		@spider.draw
		@background_image.draw(0, 0, ZOrder::BACKGROUND)
  end
end

BugGame.new.show
