// This file is auto-generated. Do not edit manually.

export const abiTermMaxFactory = [
  {
    type: 'constructor',
    inputs: [
      {
        name: 'admin',
        type: 'address',
        internalType: 'address',
      },
      {
        name: 'TERMMAX_MARKET_IMPLEMENTATION_',
        type: 'address',
        internalType: 'address',
      },
    ],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    name: 'TERMMAX_MARKET_IMPLEMENTATION',
    inputs: [],
    outputs: [
      {
        name: '',
        type: 'address',
        internalType: 'address',
      },
    ],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'acceptOwnership',
    inputs: [],
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    name: 'createMarket',
    inputs: [
      {
        name: 'gtKey',
        type: 'bytes32',
        internalType: 'bytes32',
      },
      {
        name: 'params',
        type: 'tuple',
        internalType: 'struct MarketInitialParams',
        components: [
          {
            name: 'collateral',
            type: 'address',
            internalType: 'address',
          },
          {
            name: 'debtToken',
            type: 'address',
            internalType: 'contract IERC20Metadata',
          },
          {
            name: 'admin',
            type: 'address',
            internalType: 'address',
          },
          {
            name: 'gtImplementation',
            type: 'address',
            internalType: 'address',
          },
          {
            name: 'marketConfig',
            type: 'tuple',
            internalType: 'struct MarketConfig',
            components: [
              {
                name: 'treasurer',
                type: 'address',
                internalType: 'address',
              },
              {
                name: 'maturity',
                type: 'uint64',
                internalType: 'uint64',
              },
              {
                name: 'feeConfig',
                type: 'tuple',
                internalType: 'struct FeeConfig',
                components: [
                  {
                    name: 'lendTakerFeeRatio',
                    type: 'uint32',
                    internalType: 'uint32',
                  },
                  {
                    name: 'lendMakerFeeRatio',
                    type: 'uint32',
                    internalType: 'uint32',
                  },
                  {
                    name: 'borrowTakerFeeRatio',
                    type: 'uint32',
                    internalType: 'uint32',
                  },
                  {
                    name: 'borrowMakerFeeRatio',
                    type: 'uint32',
                    internalType: 'uint32',
                  },
                  {
                    name: 'mintGtFeeRatio',
                    type: 'uint32',
                    internalType: 'uint32',
                  },
                  {
                    name: 'mintGtFeeRef',
                    type: 'uint32',
                    internalType: 'uint32',
                  },
                ],
              },
            ],
          },
          {
            name: 'loanConfig',
            type: 'tuple',
            internalType: 'struct LoanConfig',
            components: [
              {
                name: 'oracle',
                type: 'address',
                internalType: 'contract IOracle',
              },
              {
                name: 'liquidationLtv',
                type: 'uint32',
                internalType: 'uint32',
              },
              {
                name: 'maxLtv',
                type: 'uint32',
                internalType: 'uint32',
              },
              {
                name: 'liquidatable',
                type: 'bool',
                internalType: 'bool',
              },
            ],
          },
          {
            name: 'gtInitalParams',
            type: 'bytes',
            internalType: 'bytes',
          },
          {
            name: 'tokenName',
            type: 'string',
            internalType: 'string',
          },
          {
            name: 'tokenSymbol',
            type: 'string',
            internalType: 'string',
          },
        ],
      },
      {
        name: 'salt',
        type: 'uint256',
        internalType: 'uint256',
      },
    ],
    outputs: [
      {
        name: 'market',
        type: 'address',
        internalType: 'address',
      },
    ],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    name: 'gtImplements',
    inputs: [
      {
        name: '',
        type: 'bytes32',
        internalType: 'bytes32',
      },
    ],
    outputs: [
      {
        name: '',
        type: 'address',
        internalType: 'address',
      },
    ],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'owner',
    inputs: [],
    outputs: [
      {
        name: '',
        type: 'address',
        internalType: 'address',
      },
    ],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'pendingOwner',
    inputs: [],
    outputs: [
      {
        name: '',
        type: 'address',
        internalType: 'address',
      },
    ],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'predictMarketAddress',
    inputs: [
      {
        name: 'deployer',
        type: 'address',
        internalType: 'address',
      },
      {
        name: 'collateral',
        type: 'address',
        internalType: 'address',
      },
      {
        name: 'debtToken',
        type: 'address',
        internalType: 'address',
      },
      {
        name: 'maturity',
        type: 'uint64',
        internalType: 'uint64',
      },
      {
        name: 'salt',
        type: 'uint256',
        internalType: 'uint256',
      },
    ],
    outputs: [
      {
        name: 'market',
        type: 'address',
        internalType: 'address',
      },
    ],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'renounceOwnership',
    inputs: [],
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    name: 'setGtImplement',
    inputs: [
      {
        name: 'gtImplementName',
        type: 'string',
        internalType: 'string',
      },
      {
        name: 'gtImplement',
        type: 'address',
        internalType: 'address',
      },
    ],
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    name: 'transferOwnership',
    inputs: [
      {
        name: 'newOwner',
        type: 'address',
        internalType: 'address',
      },
    ],
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'event',
    name: 'CreateMarket',
    inputs: [
      {
        name: 'market',
        type: 'address',
        indexed: true,
        internalType: 'address',
      },
      {
        name: 'collateral',
        type: 'address',
        indexed: true,
        internalType: 'address',
      },
      {
        name: 'debtToken',
        type: 'address',
        indexed: true,
        internalType: 'contract IERC20',
      },
    ],
    anonymous: false,
  },
  {
    type: 'event',
    name: 'CreateVault',
    inputs: [
      {
        name: 'vault',
        type: 'address',
        indexed: true,
        internalType: 'address',
      },
      {
        name: 'creator',
        type: 'address',
        indexed: true,
        internalType: 'address',
      },
      {
        name: 'initialParams',
        type: 'tuple',
        indexed: true,
        internalType: 'struct VaultInitialParams',
        components: [
          {
            name: 'admin',
            type: 'address',
            internalType: 'address',
          },
          {
            name: 'curator',
            type: 'address',
            internalType: 'address',
          },
          {
            name: 'timelock',
            type: 'uint256',
            internalType: 'uint256',
          },
          {
            name: 'asset',
            type: 'address',
            internalType: 'contract IERC20',
          },
          {
            name: 'maxCapacity',
            type: 'uint256',
            internalType: 'uint256',
          },
          {
            name: 'name',
            type: 'string',
            internalType: 'string',
          },
          {
            name: 'symbol',
            type: 'string',
            internalType: 'string',
          },
          {
            name: 'performanceFeeRate',
            type: 'uint64',
            internalType: 'uint64',
          },
        ],
      },
    ],
    anonymous: false,
  },
  {
    type: 'event',
    name: 'OwnershipTransferStarted',
    inputs: [
      {
        name: 'previousOwner',
        type: 'address',
        indexed: true,
        internalType: 'address',
      },
      {
        name: 'newOwner',
        type: 'address',
        indexed: true,
        internalType: 'address',
      },
    ],
    anonymous: false,
  },
  {
    type: 'event',
    name: 'OwnershipTransferred',
    inputs: [
      {
        name: 'previousOwner',
        type: 'address',
        indexed: true,
        internalType: 'address',
      },
      {
        name: 'newOwner',
        type: 'address',
        indexed: true,
        internalType: 'address',
      },
    ],
    anonymous: false,
  },
  {
    type: 'event',
    name: 'SetGtImplement',
    inputs: [
      {
        name: 'key',
        type: 'bytes32',
        indexed: false,
        internalType: 'bytes32',
      },
      {
        name: 'gtImplement',
        type: 'address',
        indexed: false,
        internalType: 'address',
      },
    ],
    anonymous: false,
  },
  {
    type: 'error',
    name: 'CantNotFindGtImplementation',
    inputs: [],
  },
  {
    type: 'error',
    name: 'FailedDeployment',
    inputs: [],
  },
  {
    type: 'error',
    name: 'InsufficientBalance',
    inputs: [
      {
        name: 'balance',
        type: 'uint256',
        internalType: 'uint256',
      },
      {
        name: 'needed',
        type: 'uint256',
        internalType: 'uint256',
      },
    ],
  },
  {
    type: 'error',
    name: 'InvalidImplementation',
    inputs: [],
  },
  {
    type: 'error',
    name: 'OwnableInvalidOwner',
    inputs: [
      {
        name: 'owner',
        type: 'address',
        internalType: 'address',
      },
    ],
  },
  {
    type: 'error',
    name: 'OwnableUnauthorizedAccount',
    inputs: [
      {
        name: 'account',
        type: 'address',
        internalType: 'address',
      },
    ],
  },
] as const;
