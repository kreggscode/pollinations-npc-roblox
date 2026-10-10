local Config = {}

Config.BASE_URL = "https://gen.pollinations.ai"
Config.SECRET_NAME = "POLLINATIONS_API_KEY"
Config.API_KEY_ATTRIBUTE = "PollinationsApiKey"
Config.DEFAULT_MODEL = "nova-fast"
Config.DEFAULT_MAX_TOKENS = 120
Config.DEFAULT_TEMPERATURE = 0.8
Config.DEFAULT_HISTORY_TURNS = 8
Config.DEFAULT_COOLDOWN = 3
Config.MAX_ATTEMPTS = 3

return Config
