#! /usr/bin/env ruby

require 'cansimng'

# Playback rate and repeats
FPS=60
#REPEATS=1
REPEATS=Float::INFINITY

# Debug prints
ECHO_SIGNALS=false

# Can settings
CanSimNG.set_canspec '/home/user/DBC/argo.cfg', '/home/user/DBC/argo.dbc'
CanSimNG.set_iface 'can0'

# Gear helper
G={:D => 4, :N => 2, :R => 1, :P => 0 }

# Demo script:
demo1=[
    dss={
        :name => "Starting values",
        :length => 2,
        :parts => [
            [:atstart, 'gear', G[:P]],
            [:atstart, 'charge', 100],
            [:atstart, 'lowBeam',1],
        ]
    },
    ds1={
        :name => "Simulation sequence 1",
        :length => 15,
        :parts => [
            [:atstart, 'gear', G[:D]],
            [:linear, 'speed', 1000, 200000],
            [:linear, 'odometer', 0, 50000],
            [:linear, 'charge', 100, 98],
            [:linear, 'batteryTemperature', 20, 30],
            [:atstart, 'propulsionBatteryFailure', 1],
            [:linear, 'rpm', 0, 4000],
            [:atstart, 'lowBeam',0],
            [:atstart, 'highBeam',1],
        ]
    },
    ds2={
        :name => "Simulation sequence 2",
        :length => 15,
        :parts => [
            [:atstart, 'gear', G[:D]],
            [:atend, 'gear', G[:P]],
            [:linear, 'speed', 200000, 0],
            [:linear, 'odometer', 5, 8],
            [:linear, 'charge', 98, 96],
            [:linear, 'rpm', 4000, 0],
            [:atstart, 'highBeam',0],
            [:atstart, 'turnSignalRight',1],
        ]
    },
    {
        :name => "pause",
        :length => 1,
        :parts => [
        ]
    },
    ds3={
        :name => "Simulation sequence 3",
        :length => 8,
        :parts => [
            [:atstart, 'gear', G[:R]],
            [:linear, 'speed', 0, 15000],
            [:linear, 'odometer', 8, 9],
            [:linear, 'charge', 96, 95],
            [:linear, 'rpm', -10000, 1000],
            [:atstart, 'turnSignalRight',0],
            [:atstart, 'turnSignalLeft',1],
        ]
    },
    ds3b={
        :name => "Simulation sequence 3b",
        :length => 8,
        :parts => [
            [:atstart, 'gear', G[:R]],
            [:linear, 'speed', 15000, 0],
            [:linear, 'odometer', 9, 10],
            [:linear, 'charge', 95, 94],
            [:linear, 'rpm', 1000, 0],
            [:atstart, 'turnSignalLeft',0],
        ]
    },
    {
        :name => "pause",
        :length => 1,
        :parts => [
        ]
    },
    ds4={
        :name => "Simulation sequence 4",
        :length => 8,
        :parts => [
            [:atstart, 'gear', G[:N]],
            [:atend, 'gear', G[:P]],
            [:atstart, 'turnSignalLeft',1],
        ]
    },
    ds4b={
        :name => "Simulation sequence 4b",
        :length => 8,
        :parts => [
            [:atstart, 'parkingLights', 1],
            [:linear, 'speed', 50000, 150000],
            
        ]
    },
    ds5={
        :name => "Simulation sequence 5",
        :length => 15,
        :parts => [
            [:atstart, 'gear', G[:D]],
            [:linear, 'speed', 150000, 500000],
            [:linear, 'odometer', 10000, 671088],
            [:linear, 'charge', 100, 10],
            [:atstart, 'parkingLights', 0],
        ]
    },
    ds6={
        :name => "Simulation sequence warning lights",
        :length => 15,
        :parts => [
            [:atstart, 'gear', G[:D]],
            [:linear, 'speed', 500000, 150000],
            [:linear, 'rpm', 655, 100],
            [:atstart, 'parkingLights', 1],
            [:atstart, 'highBeam', 1],
            [:atstart, 'lowBeam', 1],
            [:atstart, 'parkingLights', 1],
            [:atstart, 'batteryVoltage', 655],
            [:atstart, 'batteryTemperature', 210],
            [:atstart, 'powerTrainTorque', 655],
            [:atstart, 'vehiclePowerMode', 1],
            [:atstart, 'parkingBrake', 1],
            [:atstart, 'parkingBrakeFlash', 1],
            [:atstart, 'brakeFailure', 1],
            [:atstart, 'seatbeltWarning', 1],
            [:atstart, 'seatbeltWarningFlash', 1],
            [:atstart, 'propulsionBatteryFailure', 1],
            [:atstart, 'highVoltageWarning', 1],
            [:atstart, 'electricMotorFailure', 1],
            [:atstart, 'batteryFailure', 1],
            [:atstart, 'turnSignalRight',1],
            [:atend, 'reset'],
        ]
    },
]

#Run the demo
CanSimNG.run_demo(demo1, FPS, REPEATS, ECHO_SIGNALS)
