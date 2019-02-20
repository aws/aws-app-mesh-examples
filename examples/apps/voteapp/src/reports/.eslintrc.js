module.exports = {
    "env": {
        "es6": true,
        "node": true,
        "mocha": true
    },
    "extends": "eslint:recommended",
    "parserOptions": {
        "sourceType": "module",
        "ecmaVersion": 2017
    },
    "rules": {
        "indent": [
            "error",
            2
        ],
        "linebreak-style": [
            "error",
            "unix"
        ],
        "no-console": "off",
        "no-constant-condition": [
            "error",
            { "checkLoops": false }
        ],
        "no-return-await": [
            "error"
        ],
        "quotes": [
            "error",
            "single",
            { "avoidEscape": true, "allowTemplateLiterals": true }
        ],
        "semi": [
            "error",
            "always"
        ]
    }
};
