class UserWildeisenIngredient
  belongs_to :unit
end

class UserWildeisenRecipe
  has_many :user_wildeisen_recipe_to_ingredients
  has_many :user_wildeisen_recipe_to_alergic_infos
  has_many :user_wildeisen_alergic_infos, through: :user_wildeisen_recipe_to_alergic_infos
end

class UserWildeisenUnit
end

class UserWildeisenAlergicInfo
end

class UserWildeisenRecipeToAlergicInfo
  belongs_to :user_wildeisen_recipe
  belongs_to :user_wildeisen_alergic_infos
end

class UserWildeisenRecipeToIngredient
  belongs_to :user_wildeisen_recipe
  belongs_to :user_wildeisen_ingredient
end