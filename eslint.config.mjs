import {configs as yaml} from "eslint-plugin-yml"

export default [
    ...yaml["flat/standard"],
    ...yaml["flat/recommended"],
    {
        name: "yaml",
        rules: {
            "yml/plain-scalar": 0
        }
    }
];
