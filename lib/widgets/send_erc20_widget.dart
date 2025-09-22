import 'package:dynamic_sdk/dynamic_sdk.dart';
import 'package:dynamic_sdk_web3dart/dynamic_sdk_web3dart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:web3dart/web3dart.dart';

class SendErc20Widget extends StatefulWidget {
  final BaseWallet wallet;
  const SendErc20Widget({super.key, required this.wallet});

  @override
  State<SendErc20Widget> createState() => _SendErc20WidgetState();
}

class _SendErc20WidgetState extends State<SendErc20Widget> {
  final TextEditingController _erc20AddressController = TextEditingController();
  final TextEditingController _recipientController = TextEditingController();
  final TextEditingController _amountTokenController = TextEditingController();

  bool _busy = false;
  String? _error;
  String? _tokenBalanceText;
  String? _tokenSymbol;
  int? _tokenDecimals;
  String? _lastTxHash;

  @override
  void dispose() {
    _erc20AddressController.dispose();
    _recipientController.dispose();
    _amountTokenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Send ERC-20',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _erc20AddressController,
              decoration: const InputDecoration(
                labelText: 'ERC-20 Token Address (0x...)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _busy ? null : _loadTokenInfo,
                child: const Text('Load Token'),
              ),
            ),
            if (_tokenBalanceText != null) ...[
              const SizedBox(height: 8),
              Text(
                'Balance: $_tokenBalanceText${_tokenSymbol != null ? ' $_tokenSymbol' : ''}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            if (_tokenDecimals != null) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _recipientController,
                decoration: const InputDecoration(
                  labelText: 'Recipient (0x...)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _amountTokenController,
                decoration: InputDecoration(
                  labelText:
                      'Amount${_tokenSymbol != null ? ' (${_tokenSymbol})' : ''}',
                  border: const OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _busy ? null : _sendToken,
                  child: const Text('Send Token'),
                ),
              ),
              if (_lastTxHash != null) ...[
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: SelectableText(
                        'Tx Hash: $_lastTxHash',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Copy tx hash',
                      icon: const Icon(Icons.copy, size: 18),
                      onPressed: () async {
                        if (_lastTxHash == null) return;
                        await Clipboard.setData(
                          ClipboardData(text: _lastTxHash!),
                        );
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Transaction hash copied'),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _loadTokenInfo() async {
    final address = _erc20AddressController.text.trim();
    if (address.isEmpty) {
      setState(() => _error = 'Token address is required');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _tokenBalanceText = null;
      _tokenSymbol = null;
      _tokenDecimals = null;
    });
    try {
      final network = await DynamicSDK.instance.wallets.getNetwork(
        wallet: widget.wallet,
      );

      final client = DynamicSDK.instance.web3dart.createPublicClient(
        chainId: network.intValue()!,
      );

      final contract = DeployedContract(
        ContractAbi.fromJson(_erc20Abi, ''),
        EthereumAddress.fromHex(address),
      );

      final balanceOfFn = contract.function('balanceOf');
      final decimalsFn = contract.function('decimals');
      final symbolFn = contract.function('symbol');

      final balanceRes = await client.call(
        contract: contract,
        function: balanceOfFn,
        params: [EthereumAddress.fromHex(widget.wallet.address)],
      );
      final raw = balanceRes.first as BigInt;

      int decimals = 18;
      try {
        final decRes = await client.call(
          contract: contract,
          function: decimalsFn,
          params: const [],
        );
        final decDyn = decRes.first;
        if (decDyn is BigInt) {
          decimals = decDyn.toInt();
        } else if (decDyn is int) {
          decimals = decDyn;
        }
      } catch (_) {}

      String? symbol;
      try {
        final symRes = await client.call(
          contract: contract,
          function: symbolFn,
          params: const [],
        );
        final s = symRes.first;
        if (s is String) symbol = s;
      } catch (_) {}

      setState(() {
        _tokenDecimals = decimals;
        _tokenSymbol = symbol;
        _tokenBalanceText = _formatTokenAmount(raw, decimals);
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _busy = false;
      });
    }
  }

  // Removed placeholder send function since real send is implemented

  Future<void> _sendToken() async {
    final tokenAddress = _erc20AddressController.text.trim();
    final recipient = _recipientController.text.trim();
    final amountStr = _amountTokenController.text.trim();
    if (tokenAddress.isEmpty) {
      setState(() => _error = 'Token address is required');
      return;
    }
    if (_tokenDecimals == null) {
      setState(() => _error = 'Load token first to get its decimals');
      return;
    }
    if (recipient.isEmpty) {
      setState(() => _error = 'Recipient is required');
      return;
    }
    if (amountStr.isEmpty) {
      setState(() => _error = 'Amount is required');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
      _lastTxHash = null;
    });
    try {
      final amountInUnits = _parseUnits(amountStr, _tokenDecimals!);

      const List<Map<String, dynamic>> erc20Abi = [
        {
          "inputs": [
            {"internalType": "address", "name": "to", "type": "address"},
            {"internalType": "uint256", "name": "amount", "type": "uint256"},
          ],
          "name": "transfer",
          "outputs": [
            {"internalType": "bool", "name": "", "type": "bool"},
          ],
          "stateMutability": "nonpayable",
          "type": "function",
        },
      ];

      final txHash = await DynamicSDK.instance.web3dart.writeContract(
        wallet: widget.wallet,
        input: WriteContractInput(
          abi: erc20Abi,
          args: [recipient, amountInUnits],
          address: tokenAddress,
          functionName: 'transfer',
          value: BigInt.zero,
        ),
      );

      setState(() {
        _lastTxHash = txHash;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Transaction submitted')));
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _busy = false;
      });
    }
  }

  BigInt _parseUnits(String value, int decimals) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return BigInt.zero;
    final parts = trimmed.split('.');
    final integerPart = parts[0].replaceAll(RegExp(r'[^0-9]'), '');
    String fractionPart = parts.length > 1
        ? parts[1].replaceAll(RegExp(r'[^0-9]'), '')
        : '';
    if (fractionPart.length > decimals) {
      fractionPart = fractionPart.substring(0, decimals);
    }
    final paddedFraction = fractionPart.padRight(decimals, '0');
    final whole = integerPart.isEmpty ? '0' : integerPart;
    return BigInt.parse(whole) * BigInt.from(10).pow(decimals) +
        (paddedFraction.isEmpty ? BigInt.zero : BigInt.parse(paddedFraction));
  }

  String _formatTokenAmount(BigInt raw, int decimals) {
    if (decimals <= 0) return raw.toString();
    final divisor = BigInt.from(10).pow(decimals);
    final integer = raw ~/ divisor;
    final fraction = (raw % divisor).toString().padLeft(decimals, '0');
    final trimmedFraction = fraction.replaceFirst(RegExp(r'0+$'), '');
    final displayFraction = trimmedFraction.isEmpty
        ? '0'
        : trimmedFraction.substring(0, trimmedFraction.length.clamp(0, 6));
    return '$integer.$displayFraction';
  }

  static const String _erc20Abi =
      '[\n    {"constant":true,"inputs":[{"name":"","type":"address"}],"name":"balanceOf","outputs":[{"name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},\n    {"constant":true,"inputs":[],"name":"decimals","outputs":[{"name":"","type":"uint8"}],"payable":false,"stateMutability":"view","type":"function"},\n    {"constant":true,"inputs":[],"name":"symbol","outputs":[{"name":"","type":"string"}],"payable":false,"stateMutability":"view","type":"function"}\n  ]';
}
