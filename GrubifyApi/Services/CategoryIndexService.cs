using GrubifyApi.Models;
using System.Collections.Immutable;

namespace GrubifyApi.Services
{
    /// <summary>
    /// Service for managing the pre-built category index for O(1) lookups.
    /// Initialized once at application startup to ensure optimal cold-start performance.
    /// </summary>
    public interface ICategoryIndexService
    {
        ImmutableList<FoodItem>? GetItemsByCategory(string category);
    }

    public class CategoryIndexService : ICategoryIndexService
    {
        private readonly Dictionary<string, ImmutableList<FoodItem>> _categoryIndex;

        public CategoryIndexService(IEnumerable<FoodItem> foodItems)
        {
            _categoryIndex = BuildCategoryIndex(foodItems);
        }

        public ImmutableList<FoodItem>? GetItemsByCategory(string category)
        {
            _categoryIndex.TryGetValue(category, out var items);
            return items;
        }

        private static Dictionary<string, ImmutableList<FoodItem>> BuildCategoryIndex(IEnumerable<FoodItem> foodItems)
        {
            var index = new Dictionary<string, ImmutableList<FoodItem>>(StringComparer.OrdinalIgnoreCase);
            var builder = new Dictionary<string, List<FoodItem>>();

            foreach (var item in foodItems)
            {
                if (!builder.ContainsKey(item.Category))
                {
                    builder[item.Category] = new List<FoodItem>();
                }
                builder[item.Category].Add(item);
            }

            // Convert to immutable lists to prevent accidental modifications
            foreach (var kvp in builder)
            {
                index[kvp.Key] = kvp.Value.ToImmutableList();
            }
            return index;
        }
    }
}
