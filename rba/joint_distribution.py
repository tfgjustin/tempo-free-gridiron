#!/usr/bin/python
#
# joint_distribution.py - describes a two-dimensional joint distribution
#
# This class is only useful for joint probability distributions where the
# x-variable is discrete and the y-variable is Gaussian.  Don't try to use
# continuous variables for x or non-Gaussians for y!
#
# Author:  epettis@google.com (Eddie Pettis)

import math

from gaussian import Gaussian

class JointDistribution (object):
    """Describes probability distribution of a parameter."""
    def __init__(self):
        self._x_values = {}

    def __str__(self):
        retstr = ''
        all_keys = self._x_values.keys()
        all_keys.sort()
        for key in all_keys:
            retstr += '(%d, %.4f, %.4f) ' % \
                      (key, self._x_values[key].mean(),
                       self._x_values[key].variance())
        return retstr

    def mean(self, x):
        """Approximates the mean for a continuous x."""

        # Degenerate case:  exact value within the keys
        if self._x_values.has_key(x):
            return self._x_values[x].mean()

        all_x_keys = self._x_values.keys()
        all_x_keys.sort()

        # Degenerate case:  value of x exceeds any known values.  In that case,
        # we simply return the mean for the highest Gaussian bin.
        if x > all_x_keys[-1]:
            upper_key = all_x_keys[-1]
            return self._x_values[upper_key].mean()

        # Degenerate case:  value of x is less than any known values.  In that
        # case, we simply return the mean for the lowest Gaussian bin.
        if x < all_x_keys[0]:
            lower_key = all_x_keys[0]
            return self._x_values[lower_key].mean()

        # Based on the previous comparisons, we know that the value of x lies
        # between two integer keys.  We will linearly interpolate between the
        # two nearest neighbors to approximate the mean value.

        # Loop until we either run out of values or the upper limit exceeds
        # the desired value.
        for upper_x_index, x_value in enumerate(all_x_keys):
            if x_value > x:
                break

        lower_x_index = upper_x_index - 1

        lower_key = all_x_keys[lower_x_index]
        upper_key = all_x_keys[upper_x_index]

        lower_x = float(lower_key)
        upper_x = float(upper_key)
        lower_y = self._x_values[lower_key].mean()
        upper_y = self._x_values[upper_key].mean()

        slope = (upper_y - lower_y) / (upper_x - lower_x)
        estimated_y = lower_y + slope * (x - lower_x)

        """
        print '%.2f %.4f %d %.1f %.4f %d %.1f %.4f' % \
              (x, estimated_y, lower_key, lower_x, lower_y, upper_key, upper_x, upper_y)"""
        
        return estimated_y

    def Append(self, x, new_y_sample):
        x = int(x)
        if not self._x_values.has_key(x):
            self._x_values[x] = Gaussian()

        this_gaussian = self._x_values[x]
        this_gaussian.Append(new_y_sample)

    def EstimateGaussian(self, x):
        """
        Create a Gaussian to approximate the estimated x value.

        This is done by interpolation.  We compute a mean from the mean()
        above.  To compute the variance, we simply weight the variance of the
        two adjacent values.  This is a hack, but it will do for now.
        """

        # Degenerate case:  exact value within the keys
        if self._x_values.has_key(x):
            mean = self._x_values[x].mean()
            variance = self._x_values[x].variance()
            return Gaussian(mean=mean, variance=variance)

        all_x_keys = self._x_values.keys()
        all_x_keys.sort()

        # Degenerate case:  value of x exceeds any known values.  In that case,
        # we simply return the mean for the highest Gaussian bin.
        if x > all_x_keys[-1]:
            upper_key = all_x_keys[-1]
            mean = self._x_values[upper_key].mean()
            variance = self._x_values[upper_key].variance()
            return Gaussian(mean=mean, variance=variance)

        # Degenerate case:  value of x is less than any known values.  In that
        # case, we simply return the mean for the lowest Gaussian bin.
        if x < all_x_keys[0]:
            lower_key = all_x_keys[0]
            mean = self._x_values[lower_key].mean()
            variance = self._x_values[lower_key].variance()
            return Gaussian(mean=mean, variance=variance)

        # Based on the previous comparisons, we know that the value of x lies
        # between two integer keys.  We will linearly interpolate between the
        # two nearest neighbors to approximate the mean value.

        # Loop until we either run out of values or the upper limit exceeds
        # the desired value.
        for upper_x_index, x_value in enumerate(all_x_keys):
            if x_value > x:
                break

        lower_x_index = upper_x_index - 1

        lower_key = all_x_keys[lower_x_index]
        upper_key = all_x_keys[upper_x_index]

        lower_x = float(lower_key)
        upper_x = float(upper_key)

        # Estimate mean.
        lower_y = self._x_values[lower_key].mean()
        upper_y = self._x_values[upper_key].mean()
        slope = (upper_y - lower_y) / (upper_x - lower_x)
        estimated_mean = lower_y + slope * (x - lower_x)

        # Estimate variance.
        lower_y = self._x_values[lower_key].variance()
        upper_y = self._x_values[upper_key].variance()
        slope = (upper_y - lower_y) / (upper_x - lower_x)
        estimated_variance = lower_y + slope * (x - lower_x)

        return Gaussian(mean=estimated_mean, variance=estimated_variance)

    def Extend(self, many_y_samples):
        x = int(x)
        if not self._x_values.has_key(x):
            self._x_values[x] = Gaussian()

        this_gaussian = self._x_values[x]
        this_gaussian.Extend(many_y_samples)

    def Join(self, other_y_gaussian):
        x = int(x)
        if not self._x_values.has_key(x):
            self._x_values[x] = Gaussian()

        this_gaussian = self._x_values[x]
        this_gaussian.Join(other_y_gaussian)
