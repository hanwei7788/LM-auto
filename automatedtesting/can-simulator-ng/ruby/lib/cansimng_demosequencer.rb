#*!
#* \file
#* \brief file cansimng_demosequencer.rb
#*
#* Copyright of Link Motion Ltd. All rights reserved.
#*
#* Contact: info@link-motion.com
#*
#* \author Niko Vähäsarja <niko.vahasarja@nomovok.com>
#*
#* any other legal text to be defined later
#*

require 'fiber'

module DemoSequencer

    private
    # Linear interpolator for value
    def self.i_linear(name, val0, val1)
        fiber = Fiber.new do |steps|
            val=val0
            step=(val1-val0) / steps.to_f
            steps.times do
                Fiber.yield [name, val]
                val+=step
            end
            [name, val1]
        end
        return fiber
    end

    # Pseudo interpolator setting value at first frame
    def self.i_atstart(name, val=nil)
        fiber = Fiber.new do |steps|
            Fiber.yield [name, val]
            steps.times do
                Fiber.yield nil
            end
            nil
        end
        return fiber
    end

    # Pseudo interpolator setting value at last frame
    def self.i_atend(name, val=nil)
        fiber = Fiber.new do |steps|
            steps.times do
                Fiber.yield nil
            end
            [name, val]
        end
        return fiber
    end

    # Pseudo interpolator setting value at first and last frame
    def self.i_atstartend(name, start_val, end_val)
        fiber = Fiber.new do |steps|
            Fiber.yield [name, start_val]
            (steps-1).times do
                Fiber.yield nil
            end
            [name, end_val]
        end
        return fiber
    end

    # Factory function for different interpolator types
    def self.interpolate(type, *args)
        case type
        when :linear
            i_linear(*args)
        when :atstart
            i_atstart(*args)
        when :atend
            i_atend(*args)
        when :atstartend
            i_atstartend(*args)
        else
            puts 'Interpolation type not recognized "%s"' % type
            nil
        end
    end

    # Function for running array of interpolations in sync
    def self.run_interpolations(interpolations, time, fps)
        steps=time*fps
        delay=1.0/fps

        steps.times do
            yield interpolations.map {|interpolation| interpolation.resume(steps)}
            sleep delay
        end
        # yield end frame without delay, to line up with start frame
        yield interpolations.map {|interpolation| interpolation.resume(steps)}
    end

    public
    # Instantiate interpolators in scene and run them.
    def self.run_scene(scene, fps)
        interpolations=scene[:parts].map{ |part| interpolate(*part) }.compact
        run_interpolations(interpolations, scene[:length], fps) do |frame|
            yield frame
        end
    end

    # Run multiple rounds of scenes.
    def self.run_scenes(scenes, fps, rounds)
        1.upto(rounds) do |round|
            puts 'Round %d/%0.0f' % [round, rounds]
            scenes.each do |scene|
                puts 'Starting "%{name}" len: %{length}sec' % scene
                run_scene(scene, fps) do |frame|
                    yield frame
                end
                puts 'Ended "%{name}"' % scene
            end
        end
    end
end
