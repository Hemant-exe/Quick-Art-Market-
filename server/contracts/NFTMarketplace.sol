// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// Creates a new market item by listing an NFT token on the marketplace.
///@dev It inherits from the ERC721URIStorage contract, which provides the basic functionality for an NFT token storage.
///@dev It also inherits from the ReentrancyGuard contract, which provides protection against reentrancy attacks.
///@dev It defines a struct MarketItems to store information about a market item, including the token ID, seller, owner, price, and sold status.
///@dev It defines a mapping IdMarketItems that maps a token ID to a MarketItems struct, which stores information about the token's listing on the marketplace.

contract NFTMarketplace is ERC721URIStorage {
    uint256 private tokenid = 0;
    uint256 private itemsSold = 0;
    uint256 ListingPrice = 0.025 ether;

    address payable owner;
    mapping(uint256 => MarketItems) IdMarketItems;

    struct MarketItems {
        uint256 tokenid;
        address payable seller;
        address payable owner;
        uint price;
        bool sold;
    }

    /// Emits an event when a new market item is created.
    /// @param tokenid The ID of the NFT token that was listed.
    /// @param seller The address of the seller who listed the token.
    /// @param owner The address of the owner of the token.
    /// @param price The price at which the token was listed.
    /// @param sold A boolean indicating whether the token has been sold.

    event IdMarketItemsCreated(
        uint256 tokenid,
        address seller,
        address owner,
        uint price,
        bool sold
    );
    modifier onlyOwner() {
        require(msg.sender == owner, "Only Owner can call this function ");
        _;
    }

    constructor() ERC721("NFT Metaverse Token", "NFTMT") {
        tokenid = 0;
        owner = payable(msg.sender);
    }

    /// Updates the listing price for the NFT marketplace.
    /// @param price The new listing price to be set.
    /// @dev This function can only be called by the contract owner.
    function updateListingPrice(uint price) public payable onlyOwner {
        ListingPrice = price;
    }

    function getListingPrice() public view returns (uint256) {
        return ListingPrice;
    }

    /// Creates a new NFT token and lists it on the marketplace.
    /// @param _tokenURI The URI of the token's metadata.
    /// @param price The price at which the token should be listed.
    /// @return The ID of the newly created token.
    /// @dev This function creates a new NFT token and lists it on the marketplace.

    function createToken(
        string memory _tokenURI,
        uint256 price
    ) public payable returns (uint256) {
        require(price > 0, "Price must be at least 1 wei");
        tokenid += 1;
        uint256 currentTokenId = tokenid;
        _mint(msg.sender, currentTokenId);
        _setTokenURI(currentTokenId, _tokenURI);

        createMarketItem(currentTokenId, price);

        return currentTokenId;
    }

    /// Creates a new market item by listing an NFT token on the marketplace.
    /// @param _tokenid The ID of the NFT token to be listed.
    /// @param price The price at which the token should be listed.
    /// @dev This function is called internally by the `createToken` function to list a newly minted NFT token on the marketplace.

    function createMarketItem(uint256 _tokenid, uint256 price) private {
        require(price > 0, "price must be greater than zero");
        require(
            msg.value >= ListingPrice,
            "balance must be grater than or equal to listing price"
        );
        IdMarketItems[_tokenid] = MarketItems(
            _tokenid,
            payable(msg.sender),
            payable(address(this)),
            price,
            false
        );
        _transfer(msg.sender, address(this), _tokenid);
        emit IdMarketItemsCreated(
            _tokenid,
            msg.sender,
            address(this),
            price,
            false
        );
    }

    /// @notice Allows the owner of an NFT token to re-sell it on the marketplace.
    /// @param _tokenid The ID of the NFT token to be re-sold.
    /// @param price The new price at which the token should be listed.
    /// @return The ID of the re-listed token.
    /// @dev This function can only be called by the current owner of the token. It updates the token's listing information and transfers the token back to the marketplace contract.
    function reSellToken(
        uint256 _tokenid,
        uint256 price
    ) public payable returns (uint256) {
        require(
            IdMarketItems[_tokenid].owner == msg.sender,
            "Only owner can sell token "
        );
        require(
            msg.value == ListingPrice,
            "owner should have atleast listinig price "
        );
        require(price > 0, "price must be greater than zero");

        IdMarketItems[_tokenid].sold = false;
        IdMarketItems[_tokenid].seller = payable(address(msg.sender));
        IdMarketItems[_tokenid].price = price;
        IdMarketItems[_tokenid].owner = payable(address(this));

        itemsSold -= 1;

        _transfer(msg.sender, address(this), _tokenid);
    }

    /// @notice Allows a user to purchase an NFT listed on the marketplace.
    /// @param _tokenid The ID of the NFT token to be purchased.
    /// @dev This function can only be called by a user who is not the current owner of the token. It transfers the token to the buyer, updates the token's ownership and sale status, and transfers the sale proceeds to the original seller and the marketplace owner.
    function CreateMarketSale(uint256 _tokenid) public payable {
        uint256 price = IdMarketItems[_tokenid].price;

        require(
            msg.value == price,
            "please submit asking price to call this function "
        );
        require(
            IdMarketItems[_tokenid].owner == address(this),
            "only owner can sell token"
        );

        IdMarketItems[_tokenid].owner = payable(msg.sender);
        IdMarketItems[_tokenid].sold = true;
        IdMarketItems[_tokenid].owner = payable(address(0));
        itemsSold += 1;

        _transfer(address(this), msg.sender, _tokenid);
        payable(owner).transfer(ListingPrice); // check
        payable(IdMarketItems[_tokenid].seller).transfer(msg.value);
    }

    /// @notice Retrieves a list of all unsold NFT items listed on the marketplace.
    /// @return items An array of MarketItems representing the unsold NFT items.
    function fetchMarketItem() public view returns (MarketItems[] memory) {
        uint256 itemCount = tokenid;
        uint256 unsoldItemCount = tokenid - itemsSold;
        uint256 index = 0;
        MarketItems[] memory items = new MarketItems[](unsoldItemCount);
        for (uint256 i = 0; i < itemCount; i++) {
            if (IdMarketItems[i + 1].owner != address(this)) {
                items[index] = IdMarketItems[i + 1];
                index++;
            }
        }
        return items;
    }

    /// @notice Retrieves a list of all NFT items owned by the current user.
    /// @return items An array of MarketItems representing the NFT items owned by the current user.
    function fetchMyNFT() public view returns (MarketItems[] memory) {
        uint256 totalCount = tokenid;
        uint256 itemCount = 0;
        uint256 index = 0;
        for (uint i = 0; i < totalCount; i++) {
            if (IdMarketItems[i + 1].owner == msg.sender) {
                itemCount++;
            }
        }

        MarketItems[] memory items = new MarketItems[](itemCount);

        for (uint i = 0; i < totalCount; i++) {
            if (IdMarketItems[i + 1].owner == msg.sender) {
                MarketItems storage currentItem = IdMarketItems[i + 1];
                items[index] = currentItem;
                index++;
            }
        }
        return items;
    }

    /// @notice Retrieves a list of all NFT items listed for sale by the current user.
    /// @return items An array of MarketItems representing the NFT items listed for sale by the current user.
    function fetchListedNFT() public view returns (MarketItems[] memory) {
        uint256 totalCount = tokenid;
        uint256 itemCount = 0;
        uint256 index = 0;

        for (uint i = 0; i < totalCount; i++) {
            if (IdMarketItems[i + 1].seller == msg.sender) {
                itemCount++;
            }
        }

        MarketItems[] memory items = new MarketItems[](itemCount);
        for (uint i = 0; i < totalCount; i++) {
            MarketItems storage currentItem = IdMarketItems[i + 1];
            items[index] = currentItem;
            index++;
        }

        return items;
    }
}
