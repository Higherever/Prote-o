# Proteção Completa — CachyOS

Script de proteção completa para CachyOS Linux.

## O que faz

- Oculta seu IP real via Cloudflare WARP
- Firewall nftables restritivo (política DROP)
- Hardening do kernel (sysctl)
- Fail2Ban anti brute-force
- Atualização do sistema

## Uso

```bash
git clone https://github.com/Higherever/Prote-o.git
cd Prote-o
chmod +x instalar.sh
bash instalar.sh
```

## Verificar

Após rodar, acesse:
- https://whoer.net
- https://ipleak.net

## Comandos úteis

```bash
warp-cli status
warp-cli connect
warp-cli disconnect
sudo nft list ruleset
sudo fail2ban-client status
```