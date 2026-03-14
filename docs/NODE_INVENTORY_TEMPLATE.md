# Node Inventory Template

Use this as the source of truth while preparing the five Raspberry Pi nodes for
 the cluster.

## Planned Nodes

| Node | Role | DHCP reservation | MAC address | Notes |
| --- | --- | --- | --- | --- |
| `cluster-node-01` | control plane | pending | pending | first bootstrap node |
| `cluster-node-02` | control plane | pending | pending | joins after `cluster-node-01` |
| `cluster-node-03` | control plane | pending | pending | joins after `cluster-node-02` |
| `cluster-node-04` | worker | pending | pending | joins after control plane is healthy |
| `cluster-node-05` | worker | pending | pending | joins after control plane is healthy |

## API Endpoint

- Proposed DNS name: `cluster-api.<homelab-domain>`
- Approved DNS name: `cluster-api.<homelab-domain>`
- Initial target: `cluster-node-01` once its DHCP reservation is assigned
- Future direction: move to a VIP or other HA endpoint once the base cluster is
  healthy
