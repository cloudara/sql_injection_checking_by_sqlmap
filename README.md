Install nessessary lib first:
     brew install jq
     pip install sqlmap
Config permission:
     chmod +x run_sqlmap.sh

Add common value in config.env
Defined endpoint to api_list.json

./run_sqlmap.sh

Config api:
{
  "apis": [
    
    {
      "endpoint": "example.api",
      "method": "POST",
      "headers": [
        "Content-Type: application/json",
        "Authorization: ${TOKEN}",
        "custom: something(* if need to test custom header)",

      ],
      "body": any
    }
  ]
}

body can be undefined, {} or array object, example:
"body":  [
     {
          "Officecd": "*"
     }
]

"body": {
     "username": "admin",
     "password": "admin"
}
