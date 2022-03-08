# applications_settingsdata

#### Description
Settingsdata application is a system application in openharmony system, which provides users with database access services, such as storing and reading system time, screen brightness and other system attributes.

####  Directory Structure

```
├── entry
│   └── src
│       └── main
│           └──ets
│           │   └── MainAbility
│           └── resources
├── product
│   └── phone
│       └── src
│           └── main
│               ├── ets
│               │   ├── DataAbility           # Using DataAbility  to provide database services
│               │   └── utils                 # utils files
│               └── resources
│                   ├── base
│                   └── rawfile
│                       └── default_settings.json # settingsdata default value file
├── signature                                # Certificate files
│  
└── LICENSE                                  # Copyright license file
```

#### Contribution

1.  Fork the repository
2.  Create Feat_xxx branch
3.  Commit your code
4.  Create Pull Request
