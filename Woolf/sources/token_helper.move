/*
    Token Helper
*/
module woolf_deployer::token_helper {
    friend woolf_deployer::woolf;

    use aptos_framework::timestamp;
    use std::string::{Self, String};
    // use std::vector;
    // use woolf_deployer::config;
    use aptos_token::token::{Self, TokenDataId, TokenId};
    // use aptos_token::property_map;
    use std::option;
    use std::signer;
    use aptos_framework::account::{Self, SignerCapability};
    use woolf_deployer::config;
    use woolf_deployer::utf8_utils;
    // use aptos_framework::reconfiguration::last_reconfiguration_time;

    const COLLECTION_NAME_V1: vector<u8> = b"Woolf Game NFT";

    /// The collection does not exist. This should never happen.
    const ECOLLECTION_NOT_EXISTS: u64 = 1;

    /// Tokens require a signer to create, so this is the signer for the collection
    struct CollectionCapability has key, drop {
        capability: SignerCapability,
    }

    public fun get_token_signer_address(): address acquires CollectionCapability {
        account::get_signer_capability_address(&borrow_global<CollectionCapability>(@woolf_deployer).capability)
    }

    fun get_token_signer(): signer acquires CollectionCapability {
        account::create_signer_with_capability(&borrow_global<CollectionCapability>(@woolf_deployer).capability)
    }

    public fun collection_name_v1(): String {
        return string::utf8(COLLECTION_NAME_V1)
    }

    public(friend) fun initialize(framework: &signer) {
        // Create the resource account for token creation, so we can get it as a signer later
        let registry_seed = utf8_utils::to_string(timestamp::now_microseconds());
        string::append(&mut registry_seed, string::utf8(b"registry_seed"));
        let (token_resource, token_signer_cap) = account::create_resource_account(
            framework,
            *string::bytes(&registry_seed)
        );

        move_to(framework, CollectionCapability {
            capability: token_signer_cap,
        });

        // Set up NFT collection
        let description = string::utf8(b"woolf game NFT from overfive team");
        let collection_uri = string::utf8(b"https://woolfgame.com");
        // This turns off supply tracking, which allows for parallel execution
        let maximum_supply = 50000;
        // collection description mutable: true
        // collection URI mutable: true
        // collection max mutable: false
        let mutate_setting = vector<bool>[ true, true, false ];
        token::create_collection(
            &token_resource,
            collection_name_v1(),
            description,
            collection_uri,
            maximum_supply,
            mutate_setting
        );
    }

    public fun build_tokendata_id(
        token_resource_address: address,
        token_name: String
    ): TokenDataId {
        let collection_name = config::collection_name_v1();
        token::create_token_data_id(token_resource_address, collection_name, token_name)
    }

    public fun build_token_id(
        token_index: u64,
        property_version: u64,
    ): TokenId acquires CollectionCapability {
        let token_resource_address = get_token_signer_address();
        let token_id = token::create_token_id_raw(
            token_resource_address,
            config::collection_name_v1(),
            utf8_utils::to_string(token_index),
            property_version
        );
        token_id
    }

    public fun tokendata_exists(token_data_id: &TokenDataId): bool {
        let (creator, collection_name, token_name) = token::get_token_data_id_fields(token_data_id);
        token::check_tokendata_exists(creator, collection_name, token_name)
    }

    public(friend) fun collection_supply(): u64 acquires CollectionCapability {
        let token_resource_address = get_token_signer_address();
        let supply = token::get_collection_supply(token_resource_address, collection_name_v1());
        if (option::is_some<u64>(&supply)) {
            return option::extract(&mut supply)
        } else {
            0
        }
    }
    /// gets or creates the token data for the given domain name
    public(friend) fun ensure_token_data(
        token_name: String
    ): TokenDataId acquires CollectionCapability {
        let token_resource = &get_token_signer();

        let token_data_id = build_tokendata_id(signer::address_of(token_resource), token_name);
        if (tokendata_exists(&token_data_id)) {
            token_data_id
        } else {
            create_token_data(token_resource, token_name)
        }
    }

    fun create_token_data(
        token_resource: &signer,
        token_name: String
    ): TokenDataId {
        // Set up the NFT
        let collection_name = config::collection_name_v1();
        assert!(
            token::check_collection_exists(signer::address_of(token_resource), collection_name),
            ECOLLECTION_NOT_EXISTS
        );

        let nft_maximum: u64 = 1;
        let description = config::tokendata_description();
        let token_uri: string::String = config::tokendata_url_prefix();
        string::append(&mut token_uri, token_name);
        let royalty_payee_address: address = @woolf_deployer;
        let royalty_points_denominator: u64 = 0;
        let royalty_points_numerator: u64 = 0;
        // tokan max mutable: false
        // token URI mutable: true
        // token description mutable: true
        // token royalty mutable: false
        // token properties mutable: true
        let token_mutate_config = token::create_token_mutability_config(
            &vector<bool>[ false, true, true, false, true ]
        );

        // let type = property_map::create_property_value(&type);
        // let now = property_map::create_property_value(&timestamp::now_seconds());
        // let property_keys: vector<String> = vector[config::config_key_creation_time_sec(), config::config_key_type()];
        // let property_values: vector<vector<u8>> = vector[property_map::borrow_value(&now), property_map::borrow_value(
        //     &type
        // )];
        // let property_types: vector<String> = vector[property_map::borrow_type(&now), property_map::borrow_type(&type)];

        let property_keys: vector<String> = vector[];
        let property_values: vector<vector<u8>> = vector[];
        let property_types: vector<String> = vector[];


        token::create_tokendata(
            token_resource,
            collection_name,
            token_name,
            description,
            nft_maximum,
            token_uri,
            royalty_payee_address,
            royalty_points_denominator,
            royalty_points_numerator,
            token_mutate_config,
            property_keys,
            property_values,
            property_types
        )
    }

    public(friend) fun create_token(tokendata_id: TokenDataId): TokenId acquires CollectionCapability {
        let token_resource = get_token_signer();

        // At this point, property_version is 0
        let (_creator, collection_name, _name) = token::get_token_data_id_fields(&tokendata_id);
        assert!(token::check_collection_exists(signer::address_of(&token_resource), collection_name), 125);

        token::mint_token(&token_resource, tokendata_id, 1)
    }

    public(friend) fun transfer_token_to(sign: &signer, token_id: TokenId) acquires CollectionCapability {
        token::initialize_token_store(sign);
        token::opt_in_direct_transfer(sign, true);

        let token_resource = get_token_signer();
        token::transfer(&token_resource, token_id, signer::address_of(sign), 1);
    }
}