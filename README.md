# 🛡️ Proteção Completa — CachyOS (Gaming Safe)

Script de proteção completa para CachyOS Linux, **compatível com jogos online da Steam** (Overwatch 2, CS2, Fortnite, etc.) e anti-cheats (EAC, BattlEye, Vanguard).

## O que faz

| Camada | Descrição | Gaming Safe? |
|--------|-----------|:------------:|
| **Cloudflare WARP** | Oculta seu IP real | ✅ |
| **nftables Firewall** | Política DROP + portas Steam/Blizzard abertas | ✅ |
| **Kernel Hardening** | sysctl seguro com `ptrace_scope=1` | ✅ |
| **Fail2Ban** | Bloqueia brute-force SSH | ✅ |

## Mudanças da v3 (Gaming Safe)

O script anterior tinha problemas que impediam jogos online:

1. `kernel.yama.ptrace_scope = 2` bloqueava anti-cheats (EAC/BattlEye). Agora é `1`.
2. `kernel.kptr_restrict = 2` podia interferir com anti-cheat. Agora é `1`.
3. Firewall sem portas de jogos. Agora tem portas Steam e Blizzard liberadas.
4. ICMP restrito. Agora aceita todo ICMP.

## Instalação

```bash
git clone https://github.com/Higherever/Prote-o.git
cd Prote-o
chmod +x instalar.sh
bash instalar.sh
```

## Verificar após instalar

- https://whoer.net
- https://ipleak.net

## Comandos úteis

```bash
warp-cli status
warp-cli disconnect
warp-cli connect
sudo nft list ruleset
sudo fail2ban-client status
sysctl kernel.yama.ptrace_scope
```

## Se um jogo não abrir

1. Desconecte o WARP: `warp-cli disconnect`
2. Teste o jogo
3. Se funcionar, o WARP interfere com esse jogo
4. Reconecte depois: `warp-cli connect`
