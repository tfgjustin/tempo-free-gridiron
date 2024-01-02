#!/usr/bin/python
#
# gaussian.py - describes a Gaussian distribution
#
# Author:  epettis@google.com (Eddie Pettis)

import math
import gaussian_lookup_table
import random

from distribution import Distribution

class Gaussian (Distribution):
    """Describes probability distribution of a parameter."""
    def __init__(self, floor=-10**12, ceiling=10**12, mean=0, variance=0):
        Distribution.__init__(self)
        self.Lookup = gaussian_lookup_table.lookup
        self._floor = floor
        self._ceiling = ceiling
        self._mean = mean
        self._variance = variance

    def __str__(self):
        return 'N(%.4f, %.4f)' % (self._mean, self._variance)

    def Add(self, other, self_mult_factor=1, other_mult_factor=1):
        """
        Adds two distibutions together.  You can no longer Append() of Extend()
        after performing this operation.  Because it will screw things up.
        To protect against this, we kill the functions.
        """
        self.Append = None
        self.Extend = None

        self._mean = self_mult_factor*self._mean + \
                     other_mult_factor*other.mean()
        self._variance = self_mult_factor**2 * self._variance + \
                         other_mult_factor**2 * other.variance()

    def Append(self, new_sample):
        self._samples.append(float(new_sample))
        self.Update()

    def _ComputeMean(self):
        sum = 0
        for s in self._samples:
            sum += s
        self._mean = sum / (len(self._samples)*1.0)
        return self._mean

    def _ComputeVariance(self):
        """Requires computation of mean first."""
        sum = 0
        for s in self._samples:
            sum += (s - self._mean)**2
        self._variance = sum / (len(self._samples)*1.0)

    def Extend(self, many_samples):
        self._samples.extend(many_samples)
        self.ComputeMean()
        self.ComputeVariance()

    def Generate(self):
        """Generates a gaussian random variable with N(mean,variance)."""
        mu = self._mean
        sigma = math.sqrt(self._variance)

        val = random.gauss(mu, sigma)
        return min(self._ceiling, max(self._floor, val))

    def GreaterThan(self, other):
        """Computes probability that this variable is greater than another."""

        probability = 0

        our_last_score = 0
        our_last_cdf = self.Lookup(0, self.mean(), self.variance())
        for our_score in range(0, 100):
            delta = our_score - our_last_score

            our_cdf = self.Lookup(our_score, self.mean(), self.variance())
            delta_cdf = our_cdf - our_last_cdf
            other_lt_cdf = other.Lookup(our_score, other.mean(), other.variance())

            probability += delta_cdf*other_lt_cdf

            """
            print 'F_other(%3d) = %.3f  f_us(%3d) = %.3f  += %.3f = %.3f' % \
                  (our_score, other_lt_cdf, our_score, our_cdf, delta_cdf,
                   probability)"""

            our_last_score = our_score
            our_last_cdf = our_cdf

        return probability

    def Join(self, other_gaussian):
        self._samples.extend(other_gaussian.samples())
        self.ComputeMean()
        self.ComputeVariance()

    def Subtract(self, other):
        """
        Adds two distibutions together.  You can no longer Append() of Extend()
        after performing this operation.  Because it will screw things up.
        To protect against this, we kill the functions.
        """
        self.Append = None
        self.Extend = None

        self._mean = self._mean - other.mean()
        self._variance = self._variance + other.variance()

    def Update(self):
        """Updates mean and variance properly."""
        self._ComputeMean()
        self._ComputeVariance()
