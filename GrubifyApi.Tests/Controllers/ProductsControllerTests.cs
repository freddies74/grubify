using GrubifyApi.Controllers;
using GrubifyApi.Models;
using Microsoft.AspNetCore.Mvc;

namespace GrubifyApi.Tests.Controllers;

public class ProductsControllerTests
{
    private readonly ProductsController _controller = new();

    // --- Malformed identifier tests (the incident-triggering cases) ---

    [Theory]
    [InlineData("phpPhotoAlbum")]
    [InlineData("bad397")]
    [InlineData("abc")]
    [InlineData("not-a-number")]
    [InlineData("1.5")]
    public void GetProduct_WithNonIntegerIdentifier_ReturnsBadRequest(string malformedId)
    {
        var result = _controller.GetProduct(malformedId);

        Assert.IsType<BadRequestObjectResult>(result.Result);
    }

    [Theory]
    [InlineData("0")]
    [InlineData("-1")]
    [InlineData("-999")]
    public void GetProduct_WithNonPositiveIdentifier_ReturnsBadRequest(string invalidId)
    {
        var result = _controller.GetProduct(invalidId);

        Assert.IsType<BadRequestObjectResult>(result.Result);
    }

    // --- Not-found tests ---

    [Fact]
    public void GetProduct_WithNonExistentId_ReturnsNotFound()
    {
        var result = _controller.GetProduct("99999");

        Assert.IsType<NotFoundResult>(result.Result);
    }

    // --- Success tests ---

    [Theory]
    [InlineData("1")]
    [InlineData("5")]
    [InlineData("15")]
    public void GetProduct_WithValidExistingId_ReturnsOkWithProduct(string id)
    {
        var result = _controller.GetProduct(id);

        var okResult = Assert.IsType<OkObjectResult>(result.Result);
        var product = Assert.IsType<FoodItem>(okResult.Value);
        Assert.Equal(int.Parse(id), product.Id);
    }

    [Fact]
    public void GetProducts_ReturnsAllProducts()
    {
        var result = _controller.GetProducts();

        var okResult = Assert.IsType<OkObjectResult>(result.Result);
        var products = Assert.IsAssignableFrom<IEnumerable<FoodItem>>(okResult.Value);
        Assert.NotEmpty(products);
    }

    [Fact]
    public void GetProductsByCategory_WithValidCategory_ReturnsMatchingProducts()
    {
        var result = _controller.GetProductsByCategory("Pizza");

        var okResult = Assert.IsType<OkObjectResult>(result.Result);
        var products = Assert.IsAssignableFrom<IEnumerable<FoodItem>>(okResult.Value);
        Assert.All(products, p => Assert.Equal("Pizza", p.Category, StringComparer.OrdinalIgnoreCase));
    }

    [Fact]
    public void GetProductsByCategory_WithUnknownCategory_ReturnsEmptyList()
    {
        var result = _controller.GetProductsByCategory("__probe");

        var okResult = Assert.IsType<OkObjectResult>(result.Result);
        var products = Assert.IsAssignableFrom<IEnumerable<FoodItem>>(okResult.Value);
        Assert.Empty(products);
    }
}
