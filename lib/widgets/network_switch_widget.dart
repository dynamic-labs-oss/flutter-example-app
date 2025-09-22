import 'package:dynamic_sdk/dynamic_sdk.dart';
import 'package:flutter/material.dart';

class NetworkSwitchWidget extends StatefulWidget {
  final BaseWallet wallet;
  const NetworkSwitchWidget({super.key, required this.wallet});

  @override
  State<NetworkSwitchWidget> createState() => _NetworkSwitchWidgetState();
}

class _NetworkSwitchWidgetState extends State<NetworkSwitchWidget> {
  List<GenericNetwork> _availableNetworks = const [];
  GenericNetwork? _selectedNetwork;
  bool _loading = false;
  bool _switching = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadNetworksAndCurrent();
  }

  Future<void> _loadNetworksAndCurrent() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final networks = DynamicSDK.instance.networks.evm;
      final current = await DynamicSDK.instance.wallets.getNetwork(
        wallet: widget.wallet,
      );
      final currentChainId = current.intValue();

      GenericNetwork? selected;
      if (currentChainId != null) {
        for (final n in networks) {
          if (n.chainId == currentChainId) {
            selected = n;
            break;
          }
        }
      }

      setState(() {
        _availableNetworks = networks;
        _selectedNetwork =
            selected ?? (networks.isNotEmpty ? networks.first : null);
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _switchNetwork(GenericNetwork target) async {
    setState(() {
      _switching = true;
      _error = null;
    });
    try {
      await DynamicSDK.instance.wallets.switchNetwork(
        wallet: widget.wallet,
        network: Network(target.chainId),
      );
      if (!mounted) return;
      setState(() {
        _selectedNetwork = target;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Switched to ${target.name}')));
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _switching = false;
      });
    }
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
              'Network',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (_loading)
              const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else if (_availableNetworks.isEmpty)
              const Text(
                'No networks available',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              )
            else
              DropdownButtonFormField<GenericNetwork>(
                value: _selectedNetwork,
                items: _availableNetworks
                    .map(
                      (n) => DropdownMenuItem<GenericNetwork>(
                        value: n,
                        child: Text(n.name),
                      ),
                    )
                    .toList(),
                onChanged: _switching
                    ? null
                    : (val) {
                        if (val != null) {
                          _switchNetwork(val);
                        }
                      },
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Select network',
                ),
              ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
          ],
        ),
      ),
    );
  }
}
