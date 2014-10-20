#belongs_to = keep ID in current model
#has_one = add ID to belonged model
#many = add another table IDs to current model
#many_through = map join table, add IDs to current model

module ContentfulMapping

  MAPPING = {
      'UserWildeisenUnit' => {
          contentful: 'Unit',
          type: :entry,
          fields: {},
          links: {}
      },
      'UserWildeisenAlergicInfo' => {
          contentful: 'AlergicInfo',
          type: :entry,
          fields: {},
          links: {}
      },
      'UserWildeisenIngredient' => {
          contentful: 'Ingredient',
          type: :entry,
          fields: {
          },
          links: {
              belongs_to: ['UserWildeisenUnit']
          }
      },
      'UserWildeisenRecipe' => {
          contentful: 'Recipe',
          type: :entry,
          fields: {},
          links: {
              many_through: [
                  {
                      relation_to: 'UserWildeisenAlergicInfo',
                      parent_key: :recipe_id,
                      child_key: :alergic_info_id,
                      through: 'UserWildeisenRecipeToAlergicInfo'
                  }
              ],
              many: ['UserWildeisenRecipeToIngredient']
          }
      },
      'UserWildeisenRecipeToIngredient' => {
          contentful: 'RecipeIngredient',
          type: :entry,
          fields: {},
          links: {
              belongs_to: ['UserWildeisenRecipe', 'UserWildeisenIngredient']
          }
      },
      'UserWildeisenRecipeToAlergicInfo' => {
            contentful: 'RecipeToAlergicInfo',
            fields: {
            },
            links: {
            }
        }
  }

end