package com.example.dash;

import org.bukkit.plugin.java.JavaPlugin;

public class DashPlugin extends JavaPlugin {

    @Override
    public void onEnable() {
        getServer().getPluginManager().registerEvents(new DashListener(this), this);
        getLogger().info("DashPlugin enabled!");
    }

    @Override
    public void onDisable() {
        getLogger().info("DashPlugin disabled!");
    }
}
