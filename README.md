# 🛡️ Proteção Completa — CachyOS (Gaming Safe)

Script de proteção completa para CachyOS Linux, **compatível com jogos online da Steam** (Overwatch 2, CS2, Fortnite, etc.) e anti-cheats (EAC, BattlEye, Vanguard).

## O que faz

| Camada | Descrição | Gaming Safe? |
|--------|-----------|:------------:|
| **Cloudflare WARP** | Oculta seu IP real | ✅ |
| **nftables Firewall** | Política DROP + portas Steam/Blizzard abertas | ✅ |
| **Kernel Hardening** | sysctl seguro com `ptrace_scope=1` | ✅ |
| **Fail2Ban** | Bloqueia brute-force SSH | ✅ |

## Mudanças da v2 (Gaming Safe)

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

## Portas liberadas no firewall

### Steam
- TCP: 27015-27050
- UDP: 27000-27100, 4380

### Battle.net / Overwatch 2
- TCP: 80, 443, 1119, 3074, 3724, 4000, 5040, 5222, 6113-6115
- UDP: 3478-3479, 4379-4380, 5060, 5062, 6250, 12000-64000

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