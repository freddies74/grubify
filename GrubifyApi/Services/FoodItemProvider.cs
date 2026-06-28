using GrubifyApi.Models;

namespace GrubifyApi.Services
{
    /// <summary>
    /// Service for providing access to the food items data.
    /// Centralizes food item definitions to avoid duplication across the codebase.
    /// </summary>
    public interface IFoodItemProvider
    {
        IEnumerable<FoodItem> GetAllFoodItems();
    }

    public class FoodItemProvider : IFoodItemProvider
    {
        private readonly IEnumerable<FoodItem> _foodItems;

        public FoodItemProvider(IEnumerable<FoodItem> foodItems)
        {
            _foodItems = foodItems.ToList(); // Cache items for repeated access
        }

        public IEnumerable<FoodItem> GetAllFoodItems()
        {
            return _foodItems;
        }
    }
}
