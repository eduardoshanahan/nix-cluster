# Node Inventory Template

Use this as the source of truth while preparing the five Raspberry Pi nodes for
 the cluster.

## Planned Nodes

| Node | Role | DHCP reservation | MAC address | Notes |
| --- | --- | --- | --- | --- |
| `cluster-pi-01` | control plane | `192.0.2.31` | `aa:bb:cc:dd:ee:ff` | first bootstrap node |
| `cluster-pi-02` | control plane | `192.0.2.32` | `aa:bb:cc:dd:ee:ff` | joins after `cluster-pi-01` |
| `cluster-pi-03` | control plane | `192.0.2.33` | `aa:bb:cc:dd:ee:ff` | joins after `cluster-pi-02` |
| `cluster-pi-04` | worker | `192.0.2.34` | `aa:bb:cc:dd:ee:ff` | joins after control plane is healthy |
| `cluster-pi-05` | worker | `192.0.2.35` | `aa:bb:cc:dd:ee:ff` | joins after control plane is healthy |

## API Endpoint

- Proposed DNS name: `cluster-api.<homelab-domain>`
- Approved DNS name: `cluster-api.<homelab-domain>`
- Initial target: `cluster-pi-01` once its DHCP reservation is assigned
- Future direction: move to a VIP or other HA endpoint once the base cluster is
  healthy
