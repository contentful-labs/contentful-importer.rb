#keep = keep ID in current model
#belongs = add ID to belonged model
#many_through = map join table, add IDs to current model

mapping = {
    'UserWildeisenIngredient' => {
        contentful: 'Ingredient',
        type: :entry,
        fields: {

        },
        links: {
            belongs: 'UserWildeisenRecipe',
            keep: 'UserWildeisenUnit'
        }
    },
    'UserWildeisenRecipe' => {
        contentful: 'Recipe',
        type: :entry,
        fields: {
            name: :name,
        },
        links: {
            many_through: {
                relation_to: 'UserWildeisenIngredient',
                through: 'UserWildeisenRecipeToIngredient'
            },
            many_through: {
                relation_to: 'UserWildeisenAlergicInfo',
                through: 'UserWildeisenRecipeToAlergicInfo'
            }
        }
    }
}