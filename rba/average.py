#!/usr/bin/python
#
# average.py - describes an average computation
#
# Author:  Eddie Pettis (pettis.eddie@gmail.com)

class Average (object):
    """Simple average.  Useful when we don't care about variances."""
    def __init__(self, floor=-10**12, ceiling=10**12, mean=0.0, points=0.0):
        self._floor = floor
        self._ceiling = ceiling
        self._mean = mean
        self._points = points

    def __str__(self):
        return 'N(%.4f, 0)' % self._mean

    def mean(self):
        return self._mean

    def points(self):
        return self._points

    def Add(self, other, self_mult_factor=1, other_mult_factor=1):
        """
        Adds two distibutions together.  You can no longer Append() of Extend()
        after performing this operation.  Because it will screw things up.
        To protect against this, we kill the functions.
        """
        self._mean = self_mult_factor*self._mean + \
                     other_mult_factor*other.mean()
        self._points = self._points + other.points()

    def Append(self, new_sample):
        self._mean = ((self._points * self._mean) + new_sample) / \
            (self._points + 1)
        self._points += 1

