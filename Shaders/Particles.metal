//
//  Particles.metal
//  MetalParticles
//
//  Created by Simon Gladman on 17/01/2015.
//  Copyright (c) 2015 Simon Gladman. All rights reserved.
//
//  Thanks to: http://memkite.com/blog/2014/12/15/data-parallel-programming-with-metal-and-swift-for-iphoneipad-gpu/
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.

//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>


#include <metal_stdlib>
#include "./loki_header.metal"

using namespace metal;

bool drawParticle(texture2d<float, access::write> outTexture, float4 inParticle, float4 outParticle, float3 particleColor, bool respawnOutOfBoundsParticles, float width, float height)
{
    // Convert our color into a color with alpha space
    const float4 color = float4(particleColor.r, particleColor.g, particleColor.b, 1);
    const float spawnSpeedMultipler = 2.0;
    
    // Check that the particle is within the bounds of the "image" (frame)
    // Write particle to the out texture
    const uint2 position(inParticle[0], inParticle[1]);

    // Check if we're within the bounds of the texture (screen)
    if (position.x > 0 && position.y > 0 && position.x < width && position.y < height) {
        outTexture.write(color, position);
        return true;
    } else if (respawnOutOfBoundsParticles) {
        // If we are out of bounds and want to respawn, set position to the center
        // of the image (frame) and give it some speed in a given direction
        outParticle.x = width / 2;
        outParticle.y = height / 2;
        outParticle.z = spawnSpeedMultipler * fast::sin(inParticle[0] + inParticle[1]);
        outParticle.w = spawnSpeedMultipler * fast::cos(inParticle[0] + inParticle[1]);
    }
    
    return false;
};

float2x2 gravitationalForce(float4 particle, float4 gravityWell, float typeTweak)
{
    // Adjust mass and spin with type tweak
    const float mass = gravityWell.z * typeTweak;
    const float spin = gravityWell.w * typeTweak;

    // Convert vectors into positions
    const float2 gravityWellPosition(gravityWell.x, gravityWell.y);
    const float2 particlePosition(particle.x, particle.y);

    // Calculate distance + mass and spin forces
    const float dist = fast::max(distance_squared(particlePosition, gravityWellPosition), 0.01);
    const float massFactor = (mass / dist);
    float spinFactor = (spin / dist);
    
    float2 z = float2(((gravityWell.x - particle.x) * massFactor), ((gravityWell.y - particle.y) * spinFactor));
    float2 w = float2(((gravityWell.y - particle.y) * massFactor), ((gravityWell.x - particle.x) * -spinFactor));

    return float2x2(z, w);
}

float2 velocityToPoint(float2 origin, float2 destination, float time) {
    const float distanceX = destination.x - origin.x;
    const float distanceY = destination.y - origin.y;
    
    return float2((distanceX / time), (distanceY / time));
}

float4 applyForces(float4 particle, float4x4 inGravityWell, float dragFactor, float typeTweak, int behaviorType, bool particlesShouldMove)
{
    // TODO: Replace this with an inhouse RNG so we can remove some dependencies
    Loki rng = Loki(particle.x + 1, particle.y + 1, particle.w + particle.z);
    
    // Calculate the distance to the destination point
    const float timeToPoint = 200 * rng.rand();
    const float2 origin = float2(particle.x, particle.y);
    const float2 destination = float2(inGravityWell[0].x, inGravityWell[0].y);
    const float2 velocity = velocityToPoint(origin, destination, timeToPoint);
    const float2 previousVelocity = float2(particle.z, particle.w);

    float deltaX = previousVelocity.x + (rng.rand() - 0.5);
    float deltaY = previousVelocity.y + (rng.rand() - 0.5);
    
    // Adjust "movement" based on behavior type
    deltaX *= (behaviorType * 4);
    deltaY *= (behaviorType * 4);
    
    const float2x2 gravityA = gravitationalForce(particle, inGravityWell[0], typeTweak);
    const float2x2 gravityB = gravitationalForce(particle, inGravityWell[1], typeTweak);
    const float2x2 gravityC = gravitationalForce(particle, inGravityWell[2], typeTweak);
    const float2x2 gravityD = gravitationalForce(particle, inGravityWell[3], typeTweak);

    // When using Loki, it's as simple as just calling rand()!
    float adjustedX = particlesShouldMove ? particle.x + deltaX : particle.x;
    float adjustedY = particlesShouldMove ? particle.y + deltaY : particle.y;
    
    float4 outParticle = {0., 0., 0., 0.};
    
    // Gravity Well
    if (behaviorType == 1) {
        outParticle[0] = adjustedX + particle.z;
        outParticle[1] = adjustedY + particle.w;
        outParticle[2] = (particle.z * dragFactor) +
        gravityA[0].x + gravityB[0].x + gravityC[0].x + gravityD[0].x +
        gravityA[0].y + gravityB[0].y + gravityC[0].y + gravityD[0].y;

        outParticle[3] = (particle.w * dragFactor) +
        gravityA[1].x + gravityB[1].x + gravityC[1].x + gravityD[1].x +
        gravityA[1].y + gravityB[1].y + gravityC[1].y + gravityD[1].y;
        
    // Explosion point
    } else if (behaviorType == 2) {
        
        // Calculate distance of the particle to the first gravity well
        const float2 gravityWellZeroPosition = float2(inGravityWell[0].x, inGravityWell[0].y);
        const float2 particlePositionAFloat(particle.x, particle.y);
        const float distanceZeroA = fast::max(distance_squared(particlePositionAFloat, gravityWellZeroPosition), 0.01);
        
        outParticle[0] = distanceZeroA > 100 ? adjustedX : adjustedX + -velocity.x;
        outParticle[1] = distanceZeroA > 100 ? adjustedY : adjustedY + -velocity.y;
        outParticle[2] = velocity.x * 1.15;
        outParticle[3] = velocity.y * 1.15;
        
    // Follow
    } else if (behaviorType == 3) {
        outParticle[0] = adjustedX + velocity.x;
        outParticle[1] = adjustedY + velocity.y;
        outParticle[2] = velocity.x;
        outParticle[3] = velocity.y;
    // None
    } else {
        outParticle[0] = adjustedX;
        outParticle[1] = adjustedY;
        outParticle[2] = deltaX;
        outParticle[3] = deltaY;
    }
    
    return outParticle;
    
}

kernel void particleRendererShader(texture2d<float, access::write> outTexture [[texture(0)]],
                                   const device float2x4 *inParticles [[ buffer(0) ]],
                                   device float2x4 *outParticles [[ buffer(1) ]],
                                   constant float4x4 &inGravityWell [[ buffer(2) ]],
                                   constant float3 &particleColor [[ buffer(3) ]],
                                   constant float &imageWidth [[ buffer(4) ]],
                                   constant float &imageHeight [[ buffer(5) ]],
                                   constant float &dragFactor [[ buffer(6) ]],
                                   constant bool &respawnOutOfBoundsParticles [[ buffer(7) ]],
                                   constant int &behaviorType [[ buffer(8) ]],
                                   constant bool &particlesShouldMove [[ buffer(9) ]],
                                   
                                   uint id [[thread_position_in_grid]])
{
    // Grab specific particle given thread position id
    const float2x4 inParticle = inParticles[id];
    float2x4 output;

    // Loop through each 'inParticle' to draw it and apply forces based on params
    for (int i = 0; i < 2; i++) {
        const float4 particle = inParticle[i];
        float4 outParticle = {0, 0, 0, 0};
        
        // Draw particle on the outTexture
        const bool didDrawParticle = drawParticle(outTexture, particle, outParticle, particleColor, respawnOutOfBoundsParticles, imageWidth, imageHeight);
        
        // RNG to customize behavior of particle
        const uint type = id % 3;
        const float typeTweak = 1 + type;
        
        // Apply our forces based on our params to each particle
        if (didDrawParticle == true) {
            outParticle = applyForces(particle, inGravityWell, dragFactor, typeTweak, behaviorType, particlesShouldMove);
        }
        
        output[i] = outParticle;
    }
    
    outParticles[id] = output;
}
