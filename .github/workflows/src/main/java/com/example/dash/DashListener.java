package com.example.dash;

import net.kyori.adventure.text.Component;
import net.kyori.adventure.text.format.NamedTextColor;
import org.bukkit.Location;
import org.bukkit.Sound;
import org.bukkit.entity.Player;
import org.bukkit.event.EventHandler;
import org.bukkit.event.Listener;
import org.bukkit.event.block.Action;
import org.bukkit.event.player.PlayerInteractEvent;
import org.bukkit.inventory.EquipmentSlot;
import org.bukkit.util.Vector;

import java.util.HashMap;
import java.util.Map;
import java.util.UUID;

public class DashListener implements Listener {

    private final DashPlugin plugin;
    private final Map<UUID, Long> cooldowns = new HashMap<>();
    private static final long COOLDOWN_MS = 10_000;
    private static final double DASH_DISTANCE = 5.0;

    public DashListener(DashPlugin plugin) {
        this.plugin = plugin;
    }

    @EventHandler
    public void onPlayerInteract(PlayerInteractEvent event) {
        if (event.getHand() != EquipmentSlot.HAND) return;

        if (event.getAction() != Action.RIGHT_CLICK_AIR
                && event.getAction() != Action.RIGHT_CLICK_BLOCK) return;

        Player player = event.getPlayer();

        if (!player.isSneaking()) return;

        long now = System.currentTimeMillis();
        long lastUsed = cooldowns.getOrDefault(player.getUniqueId(), 0L);
        long remaining = (lastUsed + COOLDOWN_MS) - now;

        if (remaining > 0) {
            double seconds = remaining / 1000.0;
            player.sendActionBar(
                Component.text("Перезарядка: ", NamedTextColor.RED)
                    .append(Component.text(String.format("%.1f", seconds), NamedTextColor.YELLOW))
                    .append(Component.text(" сек", NamedTextColor.RED))
            );
            return;
        }

        cooldowns.put(player.getUniqueId(), now);

        Location loc = player.getLocation();
        Vector direction = loc.getDirection().normalize();

        Vector velocity = direction.multiply(DASH_DISTANCE * 0.4);
        velocity.setY(0.2);
        player.setVelocity(velocity);

        player.playSound(player.getLocation(), Sound.ENTITY_BREEZE_WIND_BURST, 1.0f, 1.2f);

        player.sendActionBar(
            Component.text("Рывок! 10 сек до следующего", NamedTextColor.GREEN)
        );
    }
}
