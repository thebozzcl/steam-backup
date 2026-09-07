# steam-backup

## DISCLAIMER

I vibecoded this. I've tested it as much as I can, but I haven't taken a full look at the code.
I don't make myself responsible for any mishaps, such as your account being flagged by Steam.
I can't think of a reason why that would happen, but who knows.

## What is this?

I have a pretty big Steam library. I've wondered for a while what would happen to it if something
ever happens to Valve, like if they change owners. I decided I wanted to know I would have access
to my games, no matter what.

This is a Docker Compose stack that:

1. Gets a list of all your games
2. Downloads them to a local folder.
3. It's also capable of updating existing files.

It's pretty bare-bones, but works mostly fine. It has occasional problems with downloads and
absolutely no retry mechanisms, but that kind of stuff should be solved by just running the
script again.

## Setup

### 0 - Requirements

* Docker
* Docker compose (I think it's part of Docker now, you used to have to install it separately)

This assumes you're running it on Linux. I'm not sure if it will work in Windows without WSL.

### 1 - Create `.env`

Run the following:

```
cp .env.example .env
```

Edit the values in `.env`. The comments explain what each value is.

### 2 - First time build and login

Let's get your account credentials set up

```
# Build the Docker image
docker build -t steam-updater .

# Read your credentials in the local terminal
source .env

# Run steamcmd to log in. It will ask you for your password. If you have Steam Guard
# enabled, it will ask you to verify this logon as well. You should only need to do this
# once, no other part of the process should require your password.
docker run -it --rm \
  --entrypoint /bin/bash \
  -v ${STEAMCMD_DATA_PATH}:/root/.local/share/Steam \
  steam-updater:latest \
  -c "steamcmd +login ${STEAM_USER} +quit"

# Once this runs successfully, confirm $STEAMCMD_DATA_PATH has been populated
ls -lahR ${STEAMCMD_DATA_PATH}
```

### 3 - Run it!

If you're running this from the terminal, you'll want to execute:

```
docker compose up -d
# If this command is not recognized, you might need to run:
# docker-compose up -d
```

### 4 - Running it on a schedule

TBD. I'm still running it for the first time (my game library is VERY big), I haven't had the
need to set up a schedule yet.

### 5 - Using these backups in Steam

TBD as well. I'm using this more for archival purposes.
