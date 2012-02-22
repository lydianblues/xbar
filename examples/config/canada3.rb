{
    "connections": {
        "canada_1": "mysql2://root:graceling@deimos.thirdmode.com:3307/canada",      
        "canada_2": "mysql2://root:graceling@deimos.thirdmode.com:3308/canada",      
        "canada_3": "mysql2://root:graceling@deimos.thirdmode.com:3309/canada",
        "canada_4": "mysql2://root:graceling@deimos.thirdmode.com:3310/canada"
    },
    "environments": {
        "test": {
            "shards": {
                "canada": ["canada_1", "canada_2", "canada_3", "canada_4"],
                "canada_east": "canada_1",
                "canada_central": "canada_2",
                "canada_west": "canada_3",
                "canada_north": "canada_4"
            }
        }
    }
}
