class UserWildeisenIngredient

  belongs_to :unit
  belongs_to :recipe

end

class UserWildeisenRecipe

  has_many :user_wildeisen_recipe_to_ingredients
  has_many :user_wildeisen_ingredients, through: :user_wildeisen_recipe_to_ingredients

  has_many :user_wildeisen_recipe_to_alergic_infos
  has_many :user_wildeisen_alergic_infos, through: :user_wildeisen_recipe_to_alergic_infos

end

class UserWildeisenUnit

  has_many :user_wildeisen_ingredients
  has_many :user_wildeisen_recipes

end

class UserWildeisenAlergicInfo

  has_many :user_wildeisen_recipe_to_alergic_infos
  has_many :user_wildeisen_recipes, through: :user_wildeisen_recipe_to_alergic_infos

end

class UserWildeisenRecipeToAlergicInfo
  belongs_to :user_wildeisen_recipe
  belongs_to :user_wildeisen_alergic_infos
end