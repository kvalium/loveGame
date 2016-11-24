local sti = require "lib.sti"
local anim8 = require "lib.anim8"
local inspect = require "lib.inspect"

require "character"
require "Projectile"

-- lv1 enemies
local entities = require "levels.1.badguys"
local levels = require "levels.levels"
local System = require 'lib.knife.system'

local image, spriteLayer, player, sound
-- Enabling debug mode
local debug = false

local updateMotion = System({ 'name', 'pos', 'vel' },
    function(name, pos, vel, dt)
        local badGuy = spriteLayer.sprites[name]
        local x, y = 0, 0
        local speed = 36

        -- targets the player, with velocity factor
        if badGuy.x > player.x then x = x - speed * vel.x else x = x + speed * vel.x end
        if badGuy.y > player.y then y = y - speed * vel.y else y = y + speed * vel.y end

        badGuy.body:applyForce(x, y)
        badGuy.x = badGuy.body:getX() - 8
        badGuy.y = badGuy.body:getY() - 8
    end)

-- gestion des shoots
local bullets = {}
local nb_pages = 100

local direction_player = 1;
-- game state
local state = 'intro'
local currentLevel = 1

-- player date
local playerLives = 10


function love.load()
    introLoad()
end

function love.update(dt)
    if state == 'intro' then
        introUpdate(dt)
    elseif state == 'gameover' then
        gameOverUpdate(dt)
    else
        levelUpdate(dt)
    end
end


function love.draw()
    if state == 'intro' then
        introDraw()
    elseif state == 'gameover' then
        gameOverDraw()
    else
        -- Scale world
        local scale = 2
        local screen_width = love.graphics.getWidth() / scale
        local screen_height = love.graphics.getHeight() / scale

        -- Translate world so that player is always centred
        local tx = math.floor(player.x - screen_width / 2)
        local ty = math.floor(player.y - screen_height / 2)

        -- Transform world
        love.graphics.scale(scale)
        love.graphics.translate(-tx, -ty)

        -- Draw the map and all objects within
        map:draw()

        -- draw bullets:
        love.graphics.setColor(255, 255, 255, 224)

        local i, o
        for i, o in pairs(bullets) do
            love.graphics.circle('fill', o.x, o.y, 5, 4)
        end

        if debug then
            -- Draw Collision Map
            love.graphics.setColor(255, 0, 0, 50)
            map:box2d_draw()

            -- player debug
            love.graphics.setColor(255, 255, 255, 255)
            love.graphics.polygon("line", player.body:getWorldPoints(player.shape:getPoints()))
            love.graphics.print(math.floor(player.x) .. ',' .. math.floor(player.y), player.x - 16, player.y - 16)

            -- entities debug
            love.graphics.setColor(255, 0, 0, 255)
            for _, entity in ipairs(entities) do
                local badGuy = spriteLayer.sprites[entity.name]
                love.graphics.polygon("line", badGuy.body:getWorldPoints(player.shape:getPoints()))
                love.graphics.print(math.floor(badGuy.x) .. ',' .. math.floor(badGuy.y), badGuy.x - 16, badGuy.y - 16)
            end
            love.graphics.setColor(255, 255, 255, 255)
        end

        -- "HUD"

        love.graphics.setColor(0, 100, 100, 200)
        love.graphics.rectangle('fill', player.x - 300, player.y + 130, 1000, 1000)
        love.graphics.setColor(0, 0, 0, 255)
        love.graphics.print('Lives ' .. player.lives, player.x + 120, player.y + 135)

        love.graphics.setColor(255, 255, 255, 255)


        --nombre de tirs restants
        love.graphics.setColor(0, 150, 100, 255)
        love.graphics.print("Dossier pole emplois :" .. nb_pages, player.x - 200, player.y - 150)
    end
end

function love.keyreleased(key, unicode)
    if key == 'space' then
        if nb_pages > 0 then
            local direction = math.atan2(player.y + 20, player.x + 10)
            prjt = Projectile(player.x + 10, player.y, 100, direction_player, "assets/images/paper.png")
            table.insert(bullets, prjt:draw())
            nb_pages = nb_pages - 1
        end
    end
end

--------------

-- ***********************
-- INTRO FUNCTIONS
-- ***********************

local splashScreen, splashTitle, splashCommand
local splashTransX = 0
local splashTransY = 0
local splashTransSpeed = 0.1
local splashMusic = love.audio.newSource("assets/sounds/crazy_frog_techno.wav")

-- Intro screen load
function introLoad()
    splashScreen = love.graphics.newImage("assets/images/splashScreen.png")
    splashTitle = love.graphics.newImage("assets/images/splashTitle.png")
    splashCommand = love.graphics.newImage("assets/images/splashCommand.png")
    splashMusic:play()
    splashMusic:setVolume(0.7)
end

function introUpdate(dt)
    local down = love.keyboard.isDown
    love.graphics.translate(dt, dt)

    -- splash music loop
    if splashMusic:isStopped() then
        splashMusic:play()
    end

    if down("space") then
        love.audio.stop(splashMusic)
        gameLoadLevel(currentLevel)
        state = "game"
    end
end

function introDraw()
    love.graphics.draw(splashScreen, splashTransX, splashTransY, 0, 0.8, 0.8, 0)
    love.graphics.draw(splashTitle, 0, 300)
    love.graphics.draw(splashCommand, 400, 550, 0, 0.5, 0.5)
    splashTransX = splashTransX - splashTransSpeed
    splashTransY = splashTransY - splashTransSpeed / 5
end

-- ***********************
-- GAME FUNCTIONS
-- ***********************

-- Level loader handler
function gameLoadLevel(level)
    local levelData = levels[currentLevel]
    -- Set world meter size (in pixels)
    love.physics.setMeter(48)

    -- Load a map exported to Lua from Tiled
    map = sti(levelData.map, { "box2d" })

    -- Prepare physics world with horizontal and vertical gravity
    world = love.physics.newWorld(0, 0, true)
    world:setCallbacks(beginContact, endContact, preSolve, postSolve)

    -- Prepare collision objects
    map:box2d_init(world)
    world:setCallbacks(beginContact)

    -- Create a Custom Layer
    map:addCustomLayer("Sprite Layer", 4)

    -- Add data to Custom Layer
    image = love.graphics.newImage("assets/images/sprite.png")
    spriteLayer = map.layers["Sprite Layer"]

    -- appending player
    myPlayer = Character(0, 0, "assets/images/sprite.png")
    spriteLayer.sprites = { player = myPlayer:draw() }

    -- Get player spawn object from Tiled
    local playerObj
    for k, object in pairs(map.objects) do
        if object.name == "player" then
            playerObj = object
            break
        end
    end

    player = spriteLayer.sprites.player
    player.body = love.physics.newBody(world, playerObj.x, playerObj.y, 'dynamic')
    player.body:setLinearDamping(10)
    player.body:setFixedRotation(true)
    player.shape = love.physics.newRectangleShape(14, 14)
    player.lives = playerLives
    player.fixture = love.physics.newFixture(player.body, player.shape)
    player.fixture:setUserData('Player')

    -- draw entities
    local enemyCounter = 1
    for k, enemy in pairs(map.objects) do
        if enemy.type == "enemy" then
            local char = Character(enemy.x, enemy.y)
            local entity = { name = "enemy_" .. enemyCounter }
            if enemyCounter <= #entities then
                entity = entities[enemyCounter]
                char = Character(enemy.x, enemy.y, entity.sprite, entity.sound)
            else
                table.insert(entities, entity)
            end
            spriteLayer.sprites[entity.name] = char:draw()
            local charObj = spriteLayer.sprites[entity.name]
            charObj.body = love.physics.newBody(world, enemy.x, enemy.y, 'dynamic')
            charObj.body:setLinearDamping(10)
            charObj.body:setFixedRotation(true)
            charObj.shape = love.physics.newRectangleShape(14, 14)
            charObj.fixture = love.physics.newFixture(charObj.body, charObj.shape)
            charObj.fixture:setUserData(entity.name)
            charObj.fixture:setRestitution(5)
            enemyCounter = enemyCounter + 1
        end
    end

    print(inspect(spriteLayer.sprites))

    -- Draw callback for Custom Layer
    function spriteLayer:draw()
        for _, sprite in pairs(self.sprites) do
            local x = math.floor(sprite.x)
            local y = math.floor(sprite.y)
            local r = sprite.r
            love.graphics.draw(sprite.image, x, y)
        end
    end

    map:removeLayer('spawnPoint')
    -- welcome sound
    local welcomeSound = love.audio.newSource("assets/sounds/Lets_go.wav", "static")
    welcomeSound:play()
end


function levelUpdate(dt)
    -- update entities
    for _, entity in ipairs(entities) do
        updateMotion(entity, dt)
        local obj = spriteLayer.sprites[entity.name]
    end

    local down = love.keyboard.isDown
    local up = love.keyreleased(key)

    local x, y = 0, 0
    local speed = 48

    if down("z", "up") and player.y > 8 then
        y = y - speed
        direction_player = 4
    end
    if down("s", "down") then
        y = y + speed
        direction_player = 2
    end
    if down("q", "left") and player.x > 8 then
        x = x - speed
        direction_player = 3
    end
    if down("d", "right") then
        x = x + speed
        direction_player = 1
    end

    player.body:applyForce(x, y)
    player.x = player.body:getX() - 8
    player.y = player.body:getY() - 8

    -- update bullets:
    local i, o
    for i, o in ipairs(bullets) do
        if o.dir == 1 then
            o.x = o.x + o.speed * dt
        elseif o.dir == 2 then
            o.y = o.y + o.speed * dt
        elseif o.dir == 3 then
            o.x = o.x - o.speed * dt
        elseif o.dir == 4 then
            o.y = o.y - o.speed * dt
        end
        if (o.x < -10) or (o.x > love.graphics.getWidth() + 10)
                or (o.y < -10) or (o.y > love.graphics.getHeight() + 10) then
            table.remove(bullets, i)
        end
        --            for _, entity in ipairs(entities) do
        --                if o.x >= entity.x and o.x <= entity.x + 16
        --                        or o.y >= entity.y and o.y <= entity.y + 16 then
        --                    -- on tire sur un ennemis
        --                end
        --            end
    end
    -- updates routines
    map:update(dt)
    world:update(dt)
end

-- ***********************
-- GAMEOVER FUNCTIONS
-- ***********************

function gameOverUpdate(dt)
    local down = love.keyboard.isDown
    if down("escape") then
        love.event.quit('restart')
    end
end

function gameOverDraw()
    love.graphics.print('YOU DIED!', 100, 100)
    love.graphics.print("Appuyez sur l'échap bouton pour recommencer", 200, 200)
end

-- ***********************
-- COLISSION DETECTION
-- ***********************
function beginContact(a, b, coll)
    x, y = coll:getNormal()
    -- if something collide with the players
    if a:getUserData() == 'Player' then
        -- play ennemy sound
        local ennemy = spriteLayer.sprites[b:getUserData()]
        local ennemySound = love.audio.newSource(ennemy.sound, 'static')
        ennemySound:play()
        player.lives = player.lives - 1
        if player.lives == 0 then
            state = "gameover"
        end
    end
end
