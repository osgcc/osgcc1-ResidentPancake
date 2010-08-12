import std.stdio;
import derelict.sdl.sdl;
import derelict.sdl.image;
import derelict.sdl.ttf;
import derelict.opengl.gl;
import derelict.opengl.glu;
import dlinkedlist : dlinkedlist;

import std.math;
import std.string;
import std.stream;
import std.random;

// Some useful constants.
const ScreenWidth = 800;
const ScreenHeight = 600;
const ToDeg = 180 / 3.1415926535;
const ToRad = 3.1415926535 / 180;

// Ahh, using Exceptions for normal program flow.  Don't you love abusing
// language features for the sake of getting something done in the
// last half hour of the competition?
class GameOver : Exception
{
	this()
	{
		super("");
	}
}

class GameWon : Exception
{
	this()
	{
		super("");
	}
}

// The various kinds of objects which can be loaded from level files.
// Some of these (Person, EventTrig, Door) are not used..
enum
{
	Building = 0,
	Road = 1,
	Rubble = 2,
	Person = 3,
	Ammo = 4,
	Gas = 5,
	MapTrig = 6,
	EventTrig = 7,
	Door = 8,
	Syrup = 9,
	Enemy = 10
}

// This is just in a struct to keep it grouped logicall together.  This stuff
// is updated by our message loop.
struct Input
{
public static:
	bool[512] KeyDown;
	bool[512] KeyHit;
	Uint16 MouseX, MouseY;
	bool[8] MouseDown;
	byte[8] MouseHit;
}

// See if a line segment intersects a circle.
bool lineIntersectCircle(float x1, float y1, float x2, float y2, float x3, float y3, float r)
{
	float a = (x2 - x1) * (x2 - x1) + (y2 - y1) * (y2 - y1);
	float b = 2 * ((x2 - x1) * (x1 - x3) + (y2 - y1) * (y1 - y3));
	float c = x3 * x3 + y3 * y3 + x1 * x1 + y1 * y1 - 2 * (x3 * x1 + y3 * y1) - r * r;
	
	if((b * b - 4 * a * c) < 0)
		return false;

	float u = ((x3 - x1) * (x2 - x1) + (y3 - y1) * (y2 - y1)) / 
              ((x2 - x1) * (x2 - x1) + (y2 - y1) * (y2 - y1));
              
    if(u < 0 || u > 1)
    	return false;
    
    return true;
}

// See if two circles overlap (intersect).
bool circlesOverlap(float x1, float y1, float r1, float x2, float y2, float r2)
{
	float r1sq = r1 * r1;
	float r2sq = r2 * r2;

	float dsq = (x2 - x1) * (x2 - x1) + (y2 - y1) * (y2 - y1);
	
	if(dsq <= (r1sq + r2sq))
		return true;
		
	return false;
}

// A class which holds a loaded texture.  It holds a library of textures which
// can be accessed by name, which is actually a pretty cool feature and is probably
// my favorite part of this program (yeah, sad I know).
class Texture
{
	protected uint mNum;
	protected SDL_Surface* mImg;

	private static Texture[char[]] Textures;

	// Load all the textures used by the game.
	public static void Init()
	{
		load("road", "img\\asphalt.png");
		load("building", "img\\roof.bmp");
		load("player", "img\\soldier.png");
		load("playerGlock", "img\\soldier_glock.png");
		load("playerFlame", "img\\soldier_flame.png");
		load("playerSyrup", "img\\soldier_syrup.png");
		load("rubble1", "img\\rubble1.png");
		load("rubble2", "img\\rubble2.png");
		load("bullet", "img\\bullet.png");
		load("reticle", "img\\reticle.png");
		load("fire", "img\\flame.png");
		load("syrup", "img\\syrup.png");
		load("ammobox", "img\\ammo_bullet.png");
		load("ammogas", "img\\ammo_gasoline.png");
		load("ammosyrup", "img\\ammo_syrup.png");
		load("kniferest", "img\\knife_rest.png");
		load("knifeswing", "img\\knife_swing.png");
		load("gameover", "img\\gameover.png");
		load("jemima", "img\\jemima.png");
		load("gamewon", "img\\gamewon.png");

		for(int i = 1; i <= 13; i++)
			load("pancake" ~ .toString(i), "img\\pancake" ~ .toString(i) ~ ".png");
	}

	// Load a texture from a file into the named texture cache.  A loaded texture can
	// then be accessed using the static opIndex with the name of the texture as the index.
	public static void load(char[] name, char[] file)
	{
		Textures[name] = create(file);
	}

	// Load a texture from a file and return it.  This doesn't add the texture to the
	// named texture cache.
	public static Texture create(char[] file)
	{
		Texture tex = new Texture();
		glGenTextures(1, &tex.mNum);
		glBindTexture(GL_TEXTURE_2D, tex.mNum);
		tex.mImg = IMG_Load(toStringz(file));

		if(tex.mImg is null)
			throw new Exception("Couldn't load image \"" ~ file ~ "\"");
	
		SDL_PixelFormat pf = *tex.mImg.format;
	
		with(pf)
		{
			BitsPerPixel = 32;
			BytesPerPixel = 4;
			Amask = 0xFF000000;
			Bmask = 0x00FF0000;
			Gmask = 0x0000FF00;
			Rmask = 0x000000FF;
			Rshift = 24;
			Gshift = 16;
			Bshift = 8;
			Ashift = 0;
		}
	
		SDL_Surface* newImg = SDL_ConvertSurface(tex.mImg, &pf, 0);
		SDL_FreeSurface(tex.mImg);
		tex.mImg = newImg;
	
		glTexImage2D(GL_TEXTURE_2D, 0, newImg.format.BytesPerPixel,
			newImg.w, newImg.h, 0, GL_RGBA, GL_UNSIGNED_BYTE, newImg.pixels);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);

		return tex;
	}

	// Access a loaded texture by name.
	public static Texture opIndex(char[] name)
	{
		Texture* t = (name in Textures);
		assert(t !is null, "Null texture " ~ name);
		return *t;
	}
	
	// Apply a texture to the device before drawing it.
	public void apply()
	{
		glBindTexture(GL_TEXTURE_2D, mNum);
	}

	// Make this class not instantiatable outside this module.
	private this()
	{

	}
}

// A simple but fairly flexible 2D billboarded sprite class.
class Sprite
{
	// The texture this is drawn with.
	protected Texture mTex;
	
	// The width and height, in pixels, of the sprite.
	protected uint mW;
	protected uint mH;
	
	// Old position, used for collision.
	protected float mOldX = 0;
	protected float mOldY = 0;
	
	// Current position in pixels.
	protected float mX = 0;
	protected float mY = 0;
	
	// Rotation (there's only one angle in 2D of course).
	protected float mAng = 0;
	
	// Scaling.
	protected float mXScl = 1;
	protected float mYScl = 1;
	
	// The segment of the texture assigned to this sprite that will be
	// mapped to the sprite's polygons.  This way you can stretch out
	// a sprite really big and just tile a texture across it, or you can
	// pick out a single piece of a big multi-tiled texture.
	protected float mTexX1 = 0;
	protected float mTexY1 = 0;
	protected float mTexX2 = 1;
	protected float mTexY2 = 1;
	
	// Normally you position and rotate a sprite about its center, but you
	// can offset a sprite so it's positioned and rotated about some other
	// point.
	protected float mXOffs = 0;
	protected float mYOffs = 0;
	
	// Whether or not the sprite should be drawn.
	protected bool mVisible = true;

	// Given an object type, give a Texture to assign to a sprite for this object.
	public static Texture Image(uint kind)
	{
		switch(kind)
		{
			case Building:  return Texture["building"];
			case Road:      return Texture["road"];

			case Rubble:
				if(rand() & 1)
					return Texture["rubble1"];
				else
					return Texture["rubble2"];

			case Person:    return Texture["road"];
			case Ammo:      return Texture["road"];
			case Gas:       return Texture["ammogas"];
			case MapTrig:   return Texture["road"];
			case EventTrig: return Texture["road"];
			case Door:      return Texture["road"];
			case Syrup:     return Texture["ammosyrup"];
			case Enemy:     return Texture["road"];
		}
	}

	// Create a sprite from a texture with a given width and height.
	public this(Texture tex, uint w, uint h)
	{
		mTex = tex;
		mW = w;
		mH = h;
	}
	
	// Position setter.
	public void pos(float x, float y)
	{
		mX = x;
		mY = y;
		mOldX = x;
		mOldY = y;
	}
	
	// X position setter and getter.
	public void x(float x)
	{
		mX = x;
		mOldX = x;
	}

	public float x()
	{
		return mX;
	}

	// Y position setter and getter.
	public void y(float y)
	{
		mY = y;
		mOldY = y;
	}
	
	public float y()
	{
		return mY;
	}
	
	// Move the sprite a relative (instead of absolute) amount, regardless
	// of its current orientation.
	public void xlate(float x, float y)
	{
		mX += x;
		mY += y;
	}

	// Rotation setter and getter.
	public void ang(float ang)
	{
		mAng = ang;
	}
	
	public float ang()
	{
		return mAng;
	}
	
	// Scaling setter.
	public void scl(float x, float y)
	{
		mXScl = x;
		mYScl = y;
	}

	// X Scaling setter and getter.
	public void xscl(float x)
	{
		mXScl = x;
	}
	
	public float xscl()
	{
		return mXScl;
	}
	
	// Y Scaling setter and getter.
	public void yscl(float y)
	{
		mYScl = y;
	}
	
	public float yscl()
	{
		return mYScl;
	}
	
	// Set the portion of the texture to be used to texture this sprite.
	public void texRect(float x1, float y1, float x2, float y2)
	{
		mTexX1 = x1;
		mTexY1 = y1;
		mTexX2 = x2;
		mTexY2 = y2;
	}
	
	// Offset the position/rotation point of this sprite from the default center.
	public void offset(float x, float y)
	{
		mXOffs = x;
		mYOffs = y;
	}
	
	// Position and rotate this sprite exactly the same as the other sprite.
	public void copyXform(Sprite other)
	{
		mX = other.mX;
		mY = other.mY;
		mAng = other.mAng;
		mOldX = mX;
		mOldY = mY;
	}
	
	// Move the sprite forward (i.e. up when not rotated at all) according to
	// its current angle.
	public void move(float amt)
	{
		float ang = (mAng - 90) * ToRad;
		mX += cos(ang) * amt;
		mY += sin(ang) * amt;
	}
	
	// Move the sprite both forward and side-to-side based on its current angle.
	public void move(float fwd, float side)
	{
		move(fwd);

		float ang = mAng * ToRad;
		mX += cos(ang) * side;
		mY += sin(ang) * side;
	}
	
	// See how for this sprite has moved since the last time it was drawn.
	// Some commands (i.e. those which set the position absolutely) will reset
	// these values to 0.
	public float dx()
	{
		return mX - mOldX;
	}

	public float dy()
	{
		return mY - mOldY;
	}

	// Point this sprite at a certain location.
	public void pointAt(float x, float y)
	{
		mAng = atan2(y - mY, x - mX) * ToDeg + 90;
	}
	
	// Set whether or not the sprite is visible.
	public void visible(bool v)
	{
		mVisible = v;
	}

	// Draw the sprite to the screen (if it's visible).
	public void draw()
	{
		if(!mVisible)
			return;

		glLoadIdentity();

		glTranslatef(mX, mY, 0);
		glRotatef(mAng, 0, 0, 1);
		mTex.apply();

		float w = (mW / 2) * mXScl;
		float nw = -w;
		float h = (mH / 2) * mYScl;
		float nh = -h;

		w += mXOffs;
		nw += mXOffs;
		h += mYOffs;
		nh += mYOffs;

		glBegin(GL_QUADS);
			glTexCoord2f(mTexX2, mTexY1); glVertex3f(w, nh, 0);
			glTexCoord2f(mTexX1, mTexY1); glVertex3f(nw, nh, 0);
			glTexCoord2f(mTexX1, mTexY2); glVertex3f(nw, h, 0);
			glTexCoord2f(mTexX2, mTexY2); glVertex3f(w, h, 0);
		glEnd();
		
		mOldX = mX;
		mOldY = mY;
	}
}

// The kinds of weapons available.  The Syrup gun was never finished.
enum Weapon
{
	Knife,
	Glock,
	Flame,
	Syrup
}

// The class for the human player.
class Player : Sprite
{
	// Constants, fairly self-explanatory.
	const uint MaxGlockAmmo = 20;
	const uint MaxFlameAmmo = 100;
	const uint MaxSyrupAmmo = 30;
	const uint FlameDelay = 90;

	// The player's weapon, ammo counts, and which weapons they
	// have.  We never got ammo usage in, and so you always have infinite
	// ammo.
	protected Weapon mWeapon = Weapon.Knife;

	protected uint mGlockAmmo = MaxGlockAmmo;
	protected uint mFlameAmmo = MaxFlameAmmo;
	protected uint mSyrupAmmo = MaxSyrupAmmo;

	protected bool mHaveGlock = true;
	protected bool mHaveFlame = true;
	protected bool mHaveSyrup = true;

	// For the flamethrower.
	protected bool mFiring = false;
	protected uint mLastFire;

	// For the knife.
	protected Sprite mKnifeSprite;
	protected bool mKnifing = false;
	protected uint mLastSlash;
	
	// The player's health.  This does work, there's just no display for it.
	protected int mHealth = 100;

	// Create the player.  I guess there really shouldn't be more than one..
	public this()
	{
		super(Texture["player"], 64, 64);
		offset(0, -22);
		mKnifeSprite = new Sprite(Texture["kniferest"], 64, 64);
		mKnifeSprite.offset(0, -22);
	}

	// Fire the current weapon.
	public void fire()
	{
		switch(mWeapon)
		{
			case Weapon.Knife:
				mKnifing = true;
				mKnifeSprite.mTex = Texture["knifeswing"];
				mLastSlash = SDL_GetTicks();
				break;

			case Weapon.Glock:
				Bullet b = new Bullet();
				b.copyXform(this);
				b.move(10, 12);
				b.pointAt(Input.MouseX, Input.MouseY);
				break;

			case Weapon.Flame:
				mFiring = true;
				Fire f = new Fire();
				f.copyXform(this);
				f.move(40, 12);
				f.pointAt(Input.MouseX, Input.MouseY);
				mLastFire = SDL_GetTicks();
				break;

			case Weapon.Syrup:
				// Nothing here!
				break;
		}
	}
	
	// "Unfire" the current weapon.  This puts the knife back into the default
	// position, and also stops the flamethrower.
	public void unfire()
	{
		mFiring = false;
		mKnifing = false;
		mKnifeSprite.mTex = Texture["kniferest"];
	}

	// Set the current weapon.
	public void setWeapon(Weapon weapon)
	{
		switch(weapon)
		{
			case Weapon.Knife:
				mWeapon = weapon;
				mTex = Texture["player"];
				mKnifeSprite.visible = true;
				break;

			case Weapon.Glock:
				if(mHaveGlock)
				{
					mWeapon = weapon;
					mTex = Texture["playerGlock"];
				}
				mKnifeSprite.visible = false;
				break;

			case Weapon.Flame:
				if(mHaveFlame)
				{
					mWeapon = weapon;
					mTex = Texture["playerFlame"];
				}
				mKnifeSprite.visible = false;
				break;

			case Weapon.Syrup:
				if(mHaveSyrup)
				{
					mWeapon = weapon;
					mTex = Texture["playerSyrup"];
				}
				mKnifeSprite.visible = false;
				break;
		}
	}
	
	// Give the player ammo for a certain type of gun.
	public void addAmmo(uint type)
	{
		switch(type)
		{
			case Ammo:
				mGlockAmmo += 20;
				
				if(mGlockAmmo > MaxGlockAmmo)
					mGlockAmmo = MaxGlockAmmo;
				break;
				
			case Gas:
				mFlameAmmo += 50;
				
				if(mFlameAmmo > MaxFlameAmmo)
					mFlameAmmo = MaxFlameAmmo;
				break;
				
			case Syrup:
				mSyrupAmmo += 15;

				if(mSyrupAmmo > MaxSyrupAmmo)
					mSyrupAmmo = MaxSyrupAmmo;
				break;
		}
	}
	
	// Draw the player, and if they're wielding the knife, that too.
	public override void draw()
	{
		super.draw();
		mKnifeSprite.draw();
	}
	
	// See if the given circle has been knifed by the player.
	public bool knifed(float x, float y, float r)
	{
		if(mKnifing)
		{
			mKnifeSprite.move(15);
			bool hit = circlesOverlap(mKnifeSprite.x, mKnifeSprite.y, 30, x, y, r);
			mKnifeSprite.move(-15);
			mKnifeSprite.mTex = Texture["knifeswing"];
			return hit;
		}

		return false;
	}
	
	// Damage the player.  If health drops to 0, throws a game over exception (LOL).
	public void damage(int amt)
	{
		mHealth -= amt;
		
		if(mHealth <= 0)
			throw new GameOver();
	}

	// Update the player, i.e. do controls.
	public void update(GameContext gc)
	{
		// This complicated-looking mess makes it so that if you hold
		// two direction keys, you don't go faster than if you only hold
		// one.  This way you can't get an unfair advantage by going diagonally.
		int xmove = 0;
		int ymove = 0;

		if(Input.KeyDown[SDLK_w])
			ymove -= 1;

		if(Input.KeyDown[SDLK_s])
			ymove += 1;

		if(Input.KeyDown[SDLK_a])
			xmove -= 1;

		if(Input.KeyDown[SDLK_d])
			xmove += 1;

		float moveAngle = -1;

		if(xmove < 0)
		{
			if(ymove < 0)
				moveAngle = 315;
			else if(ymove > 0)
				moveAngle = 225;
			else
				moveAngle = 270;
		}
		else if(xmove > 0)
		{
			if(ymove < 0)
				moveAngle = 45;
			else if(ymove > 0)
				moveAngle = 135;
			else
				moveAngle = 90;
		}
		else
		{
			if(ymove < 0)
				moveAngle = 0;
			else if(ymove > 0)
				moveAngle = 180;
		}

		if(moveAngle != -1)
		{
			ang = moveAngle;
			move(2);
		}

		// Face the mouse cursor.
		pointAt(Input.MouseX, Input.MouseY);

		// Weapons.
		if(Input.MouseHit[SDL_BUTTON_LEFT] > 0)
			fire();
		else if(Input.MouseHit[SDL_BUTTON_LEFT] < 0)
			unfire();

		// Keep firing the flamethrower, since it just goes until you
		// let go of the trigger.
		if(mFiring)
		{
			if(mWeapon == Weapon.Flame)
			{
				uint ticks = SDL_GetTicks();
				
				if(ticks - mLastFire > FlameDelay)
				{
					Fire f = new Fire();
					f.copyXform(this);
					f.move(40, 12);
					f.pointAt(Input.MouseX, Input.MouseY);
					mLastFire = ticks;
				}
			}
		}

		// Put the knife back into the default position after a short
		// period in order to keep the player from being able to hold
		// the knife out and just impale all the pancakes.
		if(mKnifing && (SDL_GetTicks() - mLastSlash) > 100)
		{
			mKnifing = false;
			mKnifeSprite.mTex = Texture["kniferest"];
		}
		
		// Do collision with the level.
		gc.mLevel.collideSprite(this, 20);
		
		// Make the knife sprite stick to this.
		mKnifeSprite.copyXform(this);

		// Check for collision with the screen boundaries, since this is where
		// there can be exits to other areas.
		if(mX >= ScreenWidth - 20)
		{
			char[] newScreen = gc.mLevel.inMapTrigger(mX, mY);
			
			if(newScreen is null || Pancake.thereAreSome())
				mX = ScreenWidth - 20;
			else
			{
				gc.changeLevel(newScreen);
				mX = 21;
			}
		}
		else if(mX <= 20)
		{
			char[] newScreen = gc.mLevel.inMapTrigger(mX, mY);

			if(newScreen is null || Pancake.thereAreSome())
				mX = 20;
			else
			{
				gc.changeLevel(newScreen);
				mX = ScreenWidth - 21;
			}
		}
		
		if(mY >= ScreenHeight - 20)
		{
			char[] newScreen = gc.mLevel.inMapTrigger(mX, mY);

			if(newScreen is null || Pancake.thereAreSome())
				mY = ScreenHeight - 20;
			else
			{
				gc.changeLevel(newScreen);
				mY = 21;
			}
		}
		else if(mY <= 20)
		{
			char[] newScreen = gc.mLevel.inMapTrigger(mX, mY);

			if(newScreen is null || Pancake.thereAreSome())
				mY = 20;
			else
			{
				gc.changeLevel(newScreen);
				mY = ScreenHeight - 21;
			}
		}
	}
}

// A sprite for player-shot bullets.
class Bullet : Sprite
{
	protected bool mHit = false;
	protected float mPrevX, mPrevY;

	// List of all bullets.
	protected static dlinkedlist!(Bullet) Bullets;

	static this()
	{
		Bullets = new dlinkedlist!(Bullet);
	}

	// Update all bullets.
	public static void update(GameContext gc)
	{
		Bullets.reset();

		while(!Bullets.last())
		{
			Bullet b = Bullets.data;

			if(!b.process(gc))
			{
				Bullets.remove();
				delete b;
			}
			else
				b.draw();
		}
	}

	// Delete all bullets.
	public static void deleteAll()
	{
		Bullets.reset();
		
		while(!Bullets.last())
		{
			auto b = Bullets.data;
			Bullets.remove();
			delete b;
		}
	}

	// Create a bullet.
	public this()
	{
		super(Texture["bullet"], 32, 64);
		offset(0, 32);
		Bullets.add(this);
	}
	
	// Process this bullet.  Move it forward, and see if it's gone off the screen or
	// collided with the level, in which case just kill it.
	protected bool process(GameContext gc)
	{
		if(mHit)
			return false;

		mPrevX = mX;
		mPrevY = mY;

		move(20);

		if(mX < 0 || mX > ScreenWidth || mY < 0 || mY > ScreenHeight || gc.collideWithLevel(mX, mY))
			return false;

		return true;
	}

	// See if this bullet has hit the given circle.  It uses a line-to-circle intersection
	// method so that bullets can't "skip over" objects because they're moving fast.
	protected bool hit(float x, float y, float r)
	{
		if(mHit)
			return false;

		if(lineIntersectCircle(mPrevX, mPrevY, mX, mY, x, y, r))
		{
			mHit = true;
			return true;
		}

		return false;
	}
	
	// See if any existing bullet hit this circle.
	public static bool anyHit(float x, float y, float r)
	{
		Bullets.reset();

		while(!Bullets.last())
		{
			if(Bullets.data.hit(x, y, r))
				return true;
		}
		
		return false;
	}
}

// Very similar to the player bullets, but these are shot by enemies.
class EnemyBullet : Sprite
{
	protected bool mHit = false;
	protected float mPrevX, mPrevY;

	protected static dlinkedlist!(EnemyBullet) EnemyBullets;
	
	static this()
	{
		EnemyBullets = new dlinkedlist!(EnemyBullet);
	}
	
	public static void update(GameContext gc)
	{
		EnemyBullets.reset();

		while(!EnemyBullets.last())
		{
			EnemyBullet b = EnemyBullets.data;

			if(!b.process(gc))
			{
				EnemyBullets.remove();
				delete b;
			}
			else
				b.draw();
		}
	}

	public static void deleteAll()
	{
		EnemyBullets.reset();

		while(!EnemyBullets.last())
		{
			auto b = EnemyBullets.data;
			EnemyBullets.remove();
			delete b;
		}
	}

	public this()
	{
		super(Texture["bullet"], 32, 64);
		offset(0, 32);
		EnemyBullets.add(this);
	}

	protected bool process(GameContext gc)
	{
		if(mHit)
			return false;

		mPrevX = mX;
		mPrevY = mY;

		move(20);

		if(mX < 0 || mX > ScreenWidth || mY < 0 || mY > ScreenHeight || gc.collideWithLevel(mX, mY))
			return false;
			
		// See if we hit the player.
		Player p = gc.mPlayer;

		if(lineIntersectCircle(mPrevX, mPrevY, mX, mY, p.x, p.y, 25))
		{
			p.damage(1);
			return false;
		}

		return true;
	}
}

// A single ball of flamethrower fire.  Again works similar to Bullet.
class Fire : Sprite
{
	protected bool mHit = false;
	protected float mLife = 0;

	protected static dlinkedlist!(Fire) Fires;
	
	static this()
	{
		Fires = new dlinkedlist!(Fire);
	}
	
	public static void update(GameContext gc)
	{
		Fires.reset();

		while(!Fires.last())
		{
			Fire f = Fires.data;

			if(!f.process(gc))
			{
				Fires.remove();
				delete f;
			}
			else
				f.draw();
		}
	}
	
	public static void deleteAll()
	{
		Fires.reset();

		while(!Fires.last())
		{
			auto f = Fires.data;
			Fires.remove();
			delete f;
		}
	}

	public this()
	{
		super(Texture["fire"], 32, 32);
		Fires.add(this);
	}

	protected bool process(GameContext gc)
	{
		if(mHit)
			return false;

		move((1 - mLife) * 4);
		mLife += 0.017;

		float scale = sin(mLife * 3.1415926535) * 1.5;
		scl(scale, scale);

		if(mLife >= 1 || gc.collideWithLevel(mX, mY))
			return false;

		return true;
	}
	
	protected bool hit(float x, float y, float r)
	{
		if(mHit)
			return false;

		if(circlesOverlap(mX, mY, xscl * 16, x, y, r))
		{
			mHit = true;
			return true;
		}

		return false;
	}
	
	public static bool anyHit(float x, float y, float r)
	{
		Fires.reset();

		while(!Fires.last())
		{
			if(Fires.data.hit(x, y, r))
				return true;
		}
		
		return false;
	}
}

// Yes, enemy flamethrower fireball
class EnemyFire : Sprite
{
	protected float mLife = 0;

	protected static dlinkedlist!(EnemyFire) EnemyFires;
	
	static this()
	{
		EnemyFires = new dlinkedlist!(EnemyFire);
	}
	
	public static void update(GameContext gc)
	{
		EnemyFires.reset();

		while(!EnemyFires.last())
		{
			EnemyFire f = EnemyFires.data;

			if(!f.process(gc))
			{
				EnemyFires.remove();
				delete f;
			}
			else
				f.draw();
		}
	}
	
	public static void deleteAll()
	{
		EnemyFires.reset();

		while(!EnemyFires.last())
		{
			auto f = EnemyFires.data;
			EnemyFires.remove();
			delete f;
		}
	}

	public this()
	{
		super(Texture["fire"], 32, 32);
		EnemyFires.add(this);
	}

	protected bool process(GameContext gc)
	{
		move((1 - mLife) * 5);
		mLife += 0.01;

		float scale = sin(mLife * 3.1415926535) * 2;
		scl(scale, scale);

		if(mLife >= 1 || gc.collideWithLevel(mX, mY))
			return false;
			
		// See if we hit the player.
		Player p = gc.mPlayer;

		if(circlesOverlap(mX, mY, xscl * 16, p.x, p.y, 25))
		{
			p.damage(2);
			return false;
		}

		return true;
	}
}

// The simplest (and, well, besides Jemima, only) pancake enemy.
class Pancake : Sprite
{
	// Used to make it wobble.
	protected float mTurnAngle = 0;
	
	// They're not all that strong..
	protected int mHealth = 6;

	protected static dlinkedlist!(Pancake) Pancakes;

	static this()
	{
		Pancakes = new dlinkedlist!(Pancake);
	}

	public static void update(GameContext gc)
	{
		Pancakes.reset();

		while(!Pancakes.last())
		{
			Pancake p = Pancakes.data;

			if(!p.process(gc))
			{
				Pancakes.remove();
				delete p;
			}
			else
				p.draw();
		}
	}
	
	public static void deleteAll()
	{
		Pancakes.reset();

		while(!Pancakes.last())
		{
			auto p = Pancakes.data;
			Pancakes.remove();
			delete p;
		}
	}
	
	// See if there are any living pancakes on this screen.
	public static bool thereAreSome()
	{
		return Pancakes.length() > 0;
	}

	// Make a pancake.  It's texture is randomly chosen.
	public this(float x, float y)
	{
		super(Texture["pancake" ~ .toString((rand() % 13) + 1)], 64, 53);
		pos(x, y);

		Pancakes.add(this);
	}

	// Update the pancake.
	protected bool process(GameContext gc)
	{
		Player p = gc.mPlayer;
		
		// Blindly move towards the player.  SIMPLEST AI EVER.
		pointAt(p.x, p.y);
		move(1);
		
		// Make sure we do collision detection.
		gc.mLevel.collideSprite(this, 25);
		
		// Wobble.
		mTurnAngle = (mTurnAngle + 8) % 360;
		ang = sin(mTurnAngle * ToRad) * 10;

		// See if it got hurt.
		if(Bullet.anyHit(mX, mY, 25))
			mHealth--;

		if(Fire.anyHit(mX, mY, 25))
			mHealth -= 2;

		if(gc.playerKnifed(mX, mY, 25))
		{
			mHealth--;
			pointAt(p.x, p.y);
			
			// Getting knifed shoves them back.
			move(-40);
		}

		// See if it died.
		if(mHealth <= 0)
			return false;
			
		// The "attack".  If they touch you, you lose health and
		// they bounce back a bit.
		if(circlesOverlap(p.x, p.y, 25, mX, mY, 25))
		{
			move(-60);
			p.damage(3);
		}
		
		// This is a kludge.  Since knifing them or having them attack you
		// can make them move backwards into a wall, they can end up getting
		// shoved off the screen.  I guess it could also be solved by doing another
		// collision with the level.  But basically, if a pancake gets shoved off
		// the screen, you can't progress through the game since you have to kill
		// all the pancakes before you leave the screen.  So just kill any pancakes
		// which have the misfortune of being shoved into the netherworld.
		if(mX < 0 || mX > ScreenWidth || mY < 0 || mY > ScreenHeight)
			return false;

		return true;
	}
}

// The big boss!  She's kind of like a pancake.
class Jemima : Pancake
{
	// Her AI states.
	enum State
	{
		Idle,
		Bouncing,
		Sweeping,
		Berserking
	}

	protected State mState = State.Idle;
	protected uint mLastChange;

	// Just a sort of general-purpose "timer" value to choreograph her
	// actions.
	protected float mTimeline = 0;
	
	// She can be firing in one of three ways, seen below.  0 means she's not
	// firing anything.
	protected int mFiring = 0;
	protected uint mLastShot;
	
	// Has she already turned berserk?
	protected bool mBerserked = false;

	// Create her!
	this(float x, float y)
	{
		super(x, y);
		mTex = Texture["jemima"];
		mW = 128;
		mH = 128;
		mHealth = 100;
		mLastChange = SDL_GetTicks();
		mLastShot = SDL_GetTicks();
	}
	
	protected override bool process(GameContext gc)
	{
		// Yaay state machines.
		switch(mState)
		{
			case State.Idle:
				// In the Idle state, she, uhh, sits there for a second or so.
				// Then she goes to the bouncing state.
				if((SDL_GetTicks() - mLastChange) >= 1000)
				{
					mTimeline = 0;
					mState = State.Bouncing;
				}
				break;

			case State.Bouncing:
				// When she's bouncing, she just bounces left and right, up and
				// down, firing intermittently straight down.  Pretty easy to
				// avoid her shots.
				// When she's done bouncing, she goes to the sweeping state.
				mTimeline += 0.75;

				x = sin(mTimeline * ToRad) * 250 + ScreenWidth / 2;
				y = sin(mTimeline * 6 * ToRad) * 30 + 100;
				
				mFiring = (mTimeline % 150) < 75 ? 1 : 0;

				if(mTimeline >= 1080)
				{
					x = ScreenWidth / 2;
					y = 100;
					mState = State.Sweeping;
					mTimeline = 0;
				}
				break;
			
			case State.Sweeping:
				// When she's in the sweeping state, she sits still, but fires
				// her guns in a sweeping motion around her.  Much harder to avoid
				// getting shot.
				// When she's done sweeping, she just goes back to the idle state
				// and it loops.
				mTimeline += 0.75;
				
				mFiring = (mTimeline % 360) < 180 ? 2 : 0;

				if(mTimeline >= 1080)
				{
					mState = State.Idle;
					mTimeline = 0;
					mLastChange = SDL_GetTicks();
				}
				break;
			
			case State.Berserking:
				// When her health drops below 20, she goes crazy and starts bouncing
				// all over the place, surrounding herself with flamethrower blasts.
				// She does this until she dies or you die.
				mFiring = 3;
				mTimeline = (mTimeline + 0.75) % 360;

				x = sin(mTimeline * ToRad) * 250 + ScreenWidth / 2;
				y = sin(mTimeline * 6 * ToRad) * 30 + cos(mTimeline * ToRad) * 100 + ScreenHeight / 2;
				break;
		}

		if(mFiring == 1)
		{
			// Firing mode 1 is shooting straight down from both cannons.
			uint ticks = SDL_GetTicks();

			if((ticks - mLastShot) >= 100)
			{
				mLastShot = ticks;
				EnemyBullet b = new EnemyBullet();
				b.copyXform(this);
				b.ang = 180;
				b.move(0, 20);
				b = new EnemyBullet();
				b.copyXform(this);
				b.ang = 180;
				b.move(0, -20);
			}
		}
		else if(mFiring == 2)
		{
			// Firing mode 2 is shooting a sweep of shots from sideways to straight
			// down.
			uint ticks = SDL_GetTicks();
			
			if((ticks - mLastShot) >= 100)
			{
				mLastShot = ticks;
				EnemyBullet b = new EnemyBullet();
				b.copyXform(this);
				b.move(0, 20);
				b.ang = (mTimeline % 180) / 2 + 90;
				b = new EnemyBullet();
				b.copyXform(this);
				b.move(0, -20);
				b.ang = -((mTimeline % 180) / 2 + 90);
			}
		}
		else if(mFiring == 3)
		{
			// Firing mode 3 is shooting flamethrower in all directions.
			uint ticks = SDL_GetTicks();
			
			if((ticks - mLastShot) >= 100)
			{
				mLastShot = ticks;
				EnemyFire b = new EnemyFire();
				b.copyXform(this);
				b.move(0, 20);
				b.ang = (mTimeline % 180);
				b = new EnemyFire();
				b.copyXform(this);
				b.move(0, -20);
				b.ang = -((mTimeline % 180));
			}
		}

		Player p = gc.mPlayer;
		gc.mLevel.collideSprite(this, 55);

		if(Bullet.anyHit(mX, mY, 55))
			mHealth--;

		if(Fire.anyHit(mX, mY, 55))
			mHealth -= 2;

		if(gc.playerKnifed(mX, mY, 55))
		{
			mHealth--;
			pointAt(p.x, p.y);
			move(-20);
		}

		// Go berserk if health drops below 20.
		if(mHealth <= 20 && !mBerserked)
		{
			mBerserked = true;
			mState = State.Berserking;
			mTimeline = 0;
		}

		// If she dies, yaay, you won.
		if(mHealth <= 0)
			throw new GameWon();

		ang = 0;

		// I hope you can't shove her offscreen, but just in case.
		if(mX < 0 || mX > ScreenWidth || mY < 0 || mY > ScreenHeight)
			throw new GameWon();

		return true;
	}
}

// Boxes of ammo (for the Glock, Flamethrower, or Syrup gun).  Since
// you have infinite ammo, these are just, uhh, pretty boxes which you
// can make disappear by stepping on them.
class AmmoBox : Sprite
{
	protected uint mType;

	protected static dlinkedlist!(AmmoBox) AmmoBoxes;

	static this()
	{
		AmmoBoxes = new dlinkedlist!(AmmoBox);
	}

	public static void update(GameContext gc)
	{
		AmmoBoxes.reset();

		while(!AmmoBoxes.last())
		{
			AmmoBox a = AmmoBoxes.data;

			if(!a.process(gc))
			{
				AmmoBoxes.remove();
				delete a;
			}
			else
				a.draw();
		}
	}
	
	public static void deleteAll()
	{
		AmmoBoxes.reset();

		while(!AmmoBoxes.last())
		{
			auto a = AmmoBoxes.data;
			AmmoBoxes.remove();
			delete a;
		}
	}
	
	public this(uint type, float x, float y)
	{
		super(Sprite.Image(type), 32, 32);
		mType = type;
		pos(x, y);

		AmmoBoxes.add(this);
	}

	protected bool process(GameContext gc)
	{
		Player p = gc.mPlayer;
		
		if(circlesOverlap(mX, mY, 14, p.x, p.y, 25))
		{
			p.addAmmo(mType);
			return false;
		}

		return true;
	}
}

// The currently-loaded "level" (which is really just one screen).
class Level
{
	// All the static sprites (road, buildings etc.)
	protected Sprite[] mSprites;

	struct ColArea
	{
		float x1, y1;
		float x2, y2;
		
		bool contains(float x, float y)
		{
			if(x > x1 && x < x2 && y > y1 && y < y2)
				return true;
			else
				return false;
		}
	}

	// Collision areas.
	protected ColArea[] mCollision;
	
	struct MapTrigger
	{
		float x1, y1;
		float x2, y2;
		char[] mapName;
		
		bool contains(float x, float y)
		{
			if(x > x1 && x < x2 && y > y1 && y < y2)
				return true;
			else
				return false;
		}
	}

	// Triggers to warp to other areas.
	protected MapTrigger[] mMapTriggers;

	// Load the level from a file.
	public this(char[] path)
	{
		scope input = new File(path, FileMode.In);

		while(!input.eof())
		{
			int type;
			int l, t, r, b;
			char[] text;
			
			input.read(type);
			input.read(l);
			input.read(t);
			input.read(r);
			input.read(b);
			input.read(text);
			
			switch(type)
			{
				case Building:
				case Road:
					// Buildings and roads are static sprites.  They have their
					// textures repeated over them.
					Sprite s = new Sprite(Sprite.Image(type), r - l, b - t);
					s.pos((l + r) / 2, (t + b) / 2);
					s.texRect(0, 0, (r - l) / 256.0, (b - t) / 256.0);
					mSprites ~= s;

					// Buildings also create a collision area.
					if(type == Building)
					{
						mCollision.length = mCollision.length + 1;
						
						with(mCollision[$ - 1])
						{
							x1 = l;
							y1 = t;
							x2 = r;
							y2 = b;
						}
					}

					break;

				case Rubble:
					// Rubble is also a static sprite, but it has its texture
					// stretched across it.
					Sprite s = new Sprite(Sprite.Image(type), r - l, b - t);
					s.pos((l + r) / 2, (t + b) / 2);
					mSprites ~= s;

					mCollision.length = mCollision.length + 1;

					with(mCollision[$ - 1])
					{
						x1 = l;
						y1 = t;
						x2 = r;
						y2 = b;
					}

					break;

				case MapTrig:
					// Map triggers tell what map to go to when leaving the
					// edge of the screen.
					mMapTriggers.length = mMapTriggers.length + 1;
					
					with(mMapTriggers[$ - 1])
					{
						x1 = l;
						y1 = t;
						x2 = r;
						y2 = b;
						mapName = text;
					}
					break;
					
				case Enemy:
					// Enemy pancakes.
					new Pancake(l, t);
					break;

				// Three kinds of equally noneffective ammo boxes.
				case Ammo:
					new AmmoBox(Ammo, (l + r) / 2, (t + b) / 2);
					break;
					
				case Gas:
					new AmmoBox(Gas, (l + r) / 2, (t + b) / 2);
					break;

				case Syrup:
					new AmmoBox(Syrup, (l + r) / 2, (t + b) / 2);
					break;

				default:
					break;
			}
		}
	}

	// Unload all the sprites and data from this level.
	public void unload()
	{
		foreach(s; mSprites)
			delete s;

		mSprites.length = 0;
		mCollision.length = 0;
		mMapTriggers.length = 0;
	}
	
	// Draw all the static sprites.
	public void draw()
	{
		foreach(s; mSprites)
			s.draw();
	}

	// Given a sprite and a radius, collide it against the collision areas
	// and reposition the sprite so it's not overlapping any collision areas.
	// GOD this was a pain to get right, and in fact this is the first time I've
	// gotten sliding rectangular collision correct EVER.
	public void collideSprite(Sprite s, float rad)
	{
		// OK, this collision is relatively simple, but is tricky to get right.
		// It's sliding rectangular collision, so the static collision areas are
		// rectangles and so are the moving colliding objects (player and enemies).
		// When a moving object comes into contact with a collision area, it should
		// slide along the edge of the area until it gets past it by coming to
		// a corner.
		
		// What makes this so hard is collision with the convex corners of collision
		// areas.  They are very tricky, and require a bit of "tiebreaking" in one
		// case in order to make the collision seem natural.
		
		// First we have to see how far and in what direction the sprite moved.
		float dx = s.dx();
		float dy = s.dy();

		int xdir = dx < -0.0001 ? -1 : dx > 0.0001 ? 1 : 0;
		int ydir = dy < -0.0001 ? -1 : dy > 0.0001 ? 1 : 0;

		// If the sprite didn't move, we can return because it can't have moved into
		// any collision area.
		if(xdir == 0 && ydir == 0)
			return;

		// Compute the four sides of the object.  OK, so technically it's not so
		// much a collision radius, since we're going to be checking the corners of the
		// object, but still.
		float leftX = s.x - rad;
		float rightX = s.x + rad;
		float topY = s.y - rad;
		float botY = s.y + rad;

		// Go through each collision area.
		foreach(area; mCollision)
		{
			// Flags so we know what to do for collision response.
			bool pushLeft, pushRight, pushUp, pushDown;
			
			// See which of the four corners (if any) are in the collision area.
			bool hasTL = area.contains(leftX, topY);
			bool hasTR = area.contains(rightX, topY);
			bool hasBR = area.contains(rightX, botY);
			bool hasBL = area.contains(leftX, botY);

			if(hasTL)
			{
				if(hasTR)
				{
					// Top-left and top-right, if moved up, we push back down.
					if(ydir < 0)
						pushDown = true;
				}
				else if(hasBL)
				{
					// Top-left and bottom-left, if we moved left, we push right.
					if(xdir < 0)
						pushRight = true;
				}
				else
				{
					// Now here's the tricky case: when only one of the corners of
					// the moving object's collision box is inside the collision
					// area.
					
					// If we move diagonally into the corner (i.e. in the direction
					// opposite the direction the corner points), we need to "break
					// the tie" and decide which side of the area we want to slide
					// against.  We do this by seeing whether we are further along
					// one side of the area than the other.
					
					// If we're only moving up or left, then it's easy, just push
					// the opposite direction.
					if(xdir < 0)
					{
						if(ydir < 0)
						{
							float xdiff = area.x2 - leftX;
							float ydiff = area.y2 - topY;
							
							if(xdiff >= ydiff)
								pushDown = true;
							else
								pushRight = true;
						}
						else
							pushRight = true;
					}
					else if(ydir < 0)
						pushDown = true;
				}
			}
			else if(hasTR)
			{
				// We have similar cases for all the directions.
				if(hasBR)
				{
					if(xdir > 0)
						pushLeft = true;
				}
				else
				{
					if(xdir > 0)
					{
						if(ydir < 0)
						{
							float xdiff = rightX - area.x1;
							float ydiff = area.y2 - topY;
							
							if(xdiff >= ydiff)
								pushDown = true;
							else
								pushLeft = true;
						}
						else
							pushLeft = true;
					}
					else if(ydir < 0)
						pushDown = true;
				}
			}
			else if(hasBR)
			{
				if(hasBL)
				{
					if(ydir > 0)
						pushUp = true;
				}
				else
				{
					if(xdir > 0)
					{
						if(ydir > 0)
						{
							float xdiff = rightX - area.x1;
							float ydiff = botY - area.y1;
							
							if(xdiff >= ydiff)
								pushUp = true;
							else
								pushLeft = true;
						}
						else
							pushLeft = true;
					}
					else if(ydir > 0)
						pushUp = true;
				}
			}
			else if(hasBL)
			{
				if(xdir < 0)
				{
					if(ydir > 0)
					{
						float xdiff = area.x2 - leftX;
						float ydiff = botY - area.y1;

						if(xdiff >= ydiff)
							pushUp = true;
						else
							pushRight = true;
					}
					else
						pushRight = true;
				}
				else if(ydir > 0)
					pushUp = true;
			}

			// Now that we've determined the directions we need to push the
			// sprite, push it.  We're pusing the local variables so that
			// multiple collisions can accumulate into them.
			if(pushLeft)
			{
				float diff = rightX - area.x1;
				leftX -= diff;
				rightX -= diff;
			}
			else if(pushRight)
			{
				float diff = area.x2 - leftX;
				leftX += diff;
				rightX += diff;
			}

			if(pushUp)
			{
				float diff = botY - area.y1;
				topY -= diff;
				botY -= diff;
			}
			else if(pushDown)
			{
				float diff = area.y2 - topY;
				topY += diff;
				botY += diff;
			}
		}

		// Finally reposition the sprite to the new coordinates.
		s.x = leftX + rad;
		s.y = topY + rad;
	}

	// See if a point is in a map trigger.  Returns the name of the map
	// associated with the trigger if so, or null if not.
	public char[] inMapTrigger(float x, float y)
	{
		foreach(trigger; mMapTriggers)
			if(trigger.contains(x, y))
				return trigger.mapName;

		return null;
	}
	
	// See if a point is inside any collision area.
	public bool inCollision(float x, float y)
	{
		foreach(area; mCollision)
			if(area.contains(x, y))
				return true;

		return false;
	}
}

// The sort of half-assed framework for the game, GameContext sets up
// and tears down the multimedia library and holds the main loop.
scope class GameContext
{
	// There is at any given time one level and one player in existence.
	protected Level mLevel;
	protected Player mPlayer;

	// Set up the libraries and the window.
	public this()
	{
		DerelictSDL.load();
		DerelictSDLImage.load();
		DerelictGL.load();
		DerelictGLU.load();
	
		SDL_Init(SDL_INIT_VIDEO);
	
		SDL_GL_SetAttribute(SDL_GL_DOUBLEBUFFER, 1);
		SDL_SetVideoMode(ScreenWidth, ScreenHeight, 32, SDL_OPENGL);
		SDL_WM_SetCaption("Resident Pancake", null);
		SDL_ShowCursor(SDL_DISABLE);

		Texture.Init();

		glViewport(0, 0, ScreenWidth, ScreenHeight);
		glShadeModel(GL_SMOOTH);
		glClearDepth(1);
		glDisable(GL_DEPTH_TEST);
		glEnable(GL_TEXTURE_2D);
		glEnable(GL_BLEND);
		glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
	}
	
	// Tear down the libraries.
	~this()
	{
		if(SDL_Quit !is null)
			SDL_Quit();
	
		DerelictGLU.unload();
		DerelictGL.unload();
		DerelictSDLImage.unload();
		DerelictSDL.unload();
	}

	// Handle events.  This also updates the Input structure's members.
	// Returns true if the application should continue, and false otherwise.
	public bool HandleEvents()
	{
		SDL_Event event;
		Input.KeyHit[] = false;
		Input.MouseHit[] = 0;
	
		while(SDL_PollEvent(&event))
		{
			switch(event.type)
			{
				case SDL_QUIT:
					return false;
	
				case SDL_KEYDOWN:
					Input.KeyDown[event.key.keysym.sym] = true;
					Input.KeyHit[event.key.keysym.sym] = true;
					break;
	
				case SDL_KEYUP:
					Input.KeyDown[event.key.keysym.sym] = false;
					break;
	
				case SDL_MOUSEMOTION:
					Input.MouseX = event.motion.x;
					Input.MouseY = event.motion.y;
					break;
	
				case SDL_MOUSEBUTTONDOWN:
					Input.MouseDown[event.button.button] = true;
					Input.MouseHit[event.button.button] = 1;
					break;

				case SDL_MOUSEBUTTONUP:
					Input.MouseDown[event.button.button] = false;
					Input.MouseHit[event.button.button] = -1;
					break;
	
				default:
					break;
			}
		}
	
		return true;
	}
	
	// Set up the 3D camera to render 2D stuff.
	public void setupCamera()
	{
		glMatrixMode(GL_PROJECTION);
		glLoadIdentity();
		gluOrtho2D(0, ScreenWidth, 0, ScreenHeight);
		glScalef(1, -1, 1);
		glTranslatef(0, -ScreenHeight, 0);
		glMatrixMode(GL_MODELVIEW);
	}

	// Unload the current level and load a new level.
	public void changeLevel(char[] name)
	{
		if(mLevel)
		{
			mLevel.unload();
			delete mLevel;
		}

		Bullet.deleteAll();
		EnemyBullet.deleteAll();
		Fire.deleteAll();
		EnemyFire.deleteAll();
		Pancake.deleteAll();
		AmmoBox.deleteAll();

		mLevel = new Level("codingComp\\" ~ name);

		// Hardcoding!  map12 is where Jemima is.
		if(name == "map12")
			new Jemima(400, 100);
	}

	public void main()
	{
		// Abuse of Exceptions, yaaaaaay!
		try
		{
			// Let's get started.
			setupCamera();
	
			mPlayer = new Player();
			mPlayer.pos(ScreenWidth / 2, ScreenHeight / 2);
	
			changeLevel("map12");

			// The red reticle that takes the place of the mouse cursor.
			Sprite reticle = new Sprite(Texture["reticle"], 32, 32);

			uint lastTick = SDL_GetTicks();
			
			while(HandleEvents())
			{
				// You can exit by hitting escape.
				if(Input.KeyHit[SDLK_ESCAPE])
					break;
					
				// 1-4 switch weapons.
				if(Input.KeyHit[SDLK_1])
					mPlayer.setWeapon(Weapon.Knife);
					
				if(Input.KeyHit[SDLK_2])
					mPlayer.setWeapon(Weapon.Glock);
	
				if(Input.KeyHit[SDLK_3])
					mPlayer.setWeapon(Weapon.Flame);
	
				if(Input.KeyHit[SDLK_4])
					mPlayer.setWeapon(Weapon.Syrup);
	
				// Update the player.  (Now that I think about it I don't
				// know why choosing the weapon isn't in Player.update()...).
				mPlayer.update(this);
	
				// Put the reticle where the cursor is.
				reticle.pos(Input.MouseX, Input.MouseY);
	
				// Update and draw everything.
				glClear(GL_COLOR_BUFFER_BIT);
					mLevel.draw();
					Bullet.update(this);
					EnemyBullet.update(this);
					Fire.update(this);
					EnemyFire.update(this);
					AmmoBox.update(this);
					mPlayer.draw();
					Pancake.update(this);
					reticle.draw();
				SDL_GL_SwapBuffers();
			}
		}
		catch(GameOver go)
		{
			// You died, game over.
			Sprite gameover = new Sprite(Texture["gameover"], 512, 512);
			gameover.pos(ScreenWidth / 2, ScreenHeight / 2);
			
			while(HandleEvents())
			{
				if(Input.KeyHit[SDLK_ESCAPE] || Input.KeyHit[SDLK_SPACE] || Input.KeyHit[SDLK_RETURN])
					break;
					
				glClear(GL_COLOR_BUFFER_BIT);
					gameover.draw();
				SDL_GL_SwapBuffers();
			}
		}
		catch(GameWon gw)
		{
			// You won, the end.
			Sprite gamewon = new Sprite(Texture["gamewon"], 512, 512);
			gamewon.offset(0, 256);
			gamewon.pos(ScreenWidth / 2, ScreenHeight - 512);
			
			while(HandleEvents())
			{
				if(Input.KeyHit[SDLK_ESCAPE] || Input.KeyHit[SDLK_SPACE] || Input.KeyHit[SDLK_RETURN])
					break;
					
				glClear(GL_COLOR_BUFFER_BIT);
					gamewon.draw();
				SDL_GL_SwapBuffers();
			}
		}
	}
	
	// See if a point is in any collision area in the current level.
	public bool collideWithLevel(float x, float y)
	{
		return mLevel.inCollision(x, y);
	}
	
	// See if the player knifed a certain circle.
	public bool playerKnifed(float x, float y, float r)
	{
		return mPlayer.knifed(x, y, r);
	}
}

// Application entry point.  We just create the game context and call its main function.
void main()
{
	scope context = new GameContext();
	context.main();
}