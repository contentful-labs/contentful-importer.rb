#TODO Find OWNER - POSTFIX

contentful = {
    'Ingredient' => {
        id: 'ingredient',
        note: 'Collections of ingredients',
        fields: {
            name: 'Text',
            name_plural: 'Text',
            description: 'Text',
            alergic_info: 'Text',
            active: 'Boolean',
            'Unit' => {
                id: 'unit',
                link_type: 'Entry',
            },
            'Recipe' => {
                id: 'recipe',
                type: 'Entry'
            },
        }
    },
    'Recipe' => {
        id: 'recipe',
        fields: {
            random: 'Number',
            name: 'Text',
            description: 'Text',
            active: 'Boolean',
            visibility: 'Integer',
            duration: 'Integer',
            recipe_of_day_exclude: 'Boolean',
            validated: 'Boolean',
            clicks: 'Integer',
            date_start: 'Date',
            date_stop: 'Date',
            'UserWildeisenAlergicInfo' => {
                id: 'alergic_infos',
                link_type: 'Array',
                type: 'Entry'
            },
            'UserWildeisenIngredient' => {
                id: 'ingredients',
                link_type: 'Array',
                type: 'Entry'
            }

            # 'Owner' => {   TODO Owner model doesnt exist
            #     id: 'owner',
            #     link_type: 'Entry',
            # },
        }
    },
    'Unit' => {
        id: 'unit',
        fields: {
            name: 'Text',
            description: 'Text',
            liquid: 'Boolean',
            standardunits: 'Number',
        }
    },
    'RecipeToIngredient' => {
        id: 'recipe_to_ingredient',
        fields: {
            #   postfix_id TODO postfix model doesnt exist
            is_main_ingredient: 'Boolean',
            subtitle: 'Text',
            sequence: 'Integer',
            amount: 'Number',
            info: 'Text',
            old_pre_postfix: 'Text',
            'Unit' => {
                id: 'unit',
                link_type: 'Entry',
            },
            'Recipe' => {
                id: 'recipe',
                type: 'Entry'
            },
            'Ingredient' => {
                id: 'ingredient',
                type: 'Entry'
            }
        }
    },
    'Alegric info' => {
        id: 'alergic_info',
        fields: {
            name: 'Text',
            sequence: 'Integer',
        }

    }
}

